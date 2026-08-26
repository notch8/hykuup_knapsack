---
name: deploy-regression-check
description: Capture per-tenant behaviour before a Hyku Knapsack deploy and diff it afterwards to catch silent regressions. Use when deploying a knapsack to production or staging, bumping the hyrax-webapp submodule, or when asked to verify a deploy caused no tenant-level regressions.
---

# Deploy regression check

Copy this file to `.claude/skills/deploy-regression-check/SKILL.md` in your repo to
invoke it as `/deploy-regression-check`, or just follow the steps below.

A knapsack deploy can change tenant behaviour without anything appearing in the
deploy log — 30-odd tenants is too many to eyeball. `snapshot.rb` records the state
that matters per tenant; `compare.rb` diffs a before and after capture and exits
non-zero if anything in the must-not-change set moved.

**The baseline has to be captured before the deploy.** It cannot be reconstructed
afterwards.

## Portability

`snapshot.rb`, `compare.rb` and `sequence_check.rb` work on any Hyku Knapsack.
Knapsack-specific classes are guarded, so a repo without them simply records fewer
keys rather than failing. `consortium_check.rb` is HykuUp-specific — it depends on
`TenantWorkTypeFilter` and `Consortium` — and can be ignored elsewhere.

Scripts are piped over stdin, so they run from your local checkout and never need
to be in the deployed image.

## Steps

Set the context and namespace for the environment you are deploying:

```bash
CTX=<kubectl-context>; NS=<namespace>
# Excludes components rather than matching a name: the web deployment is named
# `-hyrax-` on some environments and bare on others.
POD() { kubectl --context $CTX -n $NS get pods --no-headers | grep -E '\sRunning\s' \
  | grep -vE 'worker|nginx|solr|fcrepo|postgres|redis|memcach|acme|fits|sidekiq|cron' \
  | awk '{print $1; exit}'; }
```

**1. Before the deploy**

```bash
kubectl --context $CTX -n $NS exec -i $(POD) -- bundle exec rails runner - \
  < bin/deploy-check/snapshot.rb | sed -n '/^{/,$p' > before.json

# optional, catches a class of failure that looks like deploy fallout but isn't
kubectl --context $CTX -n $NS exec -i $(POD) -- bundle exec rails runner - \
  < bin/deploy-check/sequence_check.rb
```

The `sed` strips Rails boot warnings that precede the JSON — without it the file
will not parse.

**2. Deploy.**

**3. After the deploy** — re-resolve the pod, since the deploy replaced it:

```bash
kubectl --context $CTX -n $NS exec -i $(POD) -- bundle exec rails runner - \
  < bin/deploy-check/snapshot.rb | sed -n '/^{/,$p' > after.json

bin/deploy-check/compare.rb before.json after.json
```

## Reading the output

Fails the check — a deploy should never change these on its own:

- `available_works` — a tenant's depositors gaining or losing work types
- `themes`, `schema_classes`
- an existing feature flag whose **value** changed
- a tenant disappearing, newly erroring, or a sample work losing its thumbnail
- global registered work types, derivative labels, viewer and manifest config
- on HykuUp also `consortia` and `profile_path`

Reported but not failed: counts, vocabulary term counts, schema version, Hyrax and
Puma versions, **feature flags that appeared or vanished** (an upgrade adds flags;
that is not a regression), and any key the previous version could not report.

Identical findings across many tenants collapse to one line with a count, so a
fleet-wide change reads as one finding rather than thirty.

A non-zero exit means look closer, not necessarily that something broke — an
intended change like flipping a config flag will also fail the check, which is
correct. Read the three-or-so distinct lines and decide.

## Also worth checking by hand

The snapshot cannot see these:

- **Static assets.** Fetch the homepage, extract the fingerprinted
  `/assets/application-*.css`, and confirm it returns 200. If the nginx image bakes
  assets at build time, a bad build shows up as an unstyled site, not an error.
- **Migration duration**, against whatever `--timeout` `bin/helm_deploy` uses.
- **Behaviour under load.**

## Why `available_works` is the one to watch

`Site#available_works` is a persisted column seeded only when the Site row is
created (`Site.instance` uses `first_or_create`). Nothing recomputes it at boot or
during migration, so a deploy alone cannot change it — which is exactly why a change
there means something wrote to it, and is worth failing on.
