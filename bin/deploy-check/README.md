# Deploy regression check

A HykuUp deploy can change tenant behaviour without anything appearing in the
deploy log. `snapshot.rb` captures the state that matters per tenant, and
`compare.rb` diffs a before and after capture.

**Capture the baseline before the deploy.** It cannot be reconstructed afterwards.

| Environment | Context | Namespace |
|---|---|---|
| production | `r2-besties` | `hykuup-knapsack-production` |
| staging | `r2-friends` | `hykuup-knapsack-staging` |
| friends | `r2-friends` | `hykuup-knapsack-friends` |

```bash
CTX=r2-besties; NS=hykuup-knapsack-production
POD=$(kubectl --context $CTX -n $NS get pods --no-headers | awk '/-hyrax-[0-9a-f]/{print $1; exit}')

# Before the deploy
kubectl --context $CTX -n $NS exec -i $POD -- bundle exec rails runner - \
  < bin/deploy-check/snapshot.rb > before.json

# After (pod name changes - re-resolve it first)
POD=$(kubectl --context $CTX -n $NS get pods --no-headers | awk '/-hyrax-[0-9a-f]/{print $1; exit}')
kubectl --context $CTX -n $NS exec -i $POD -- bundle exec rails runner - \
  < bin/deploy-check/snapshot.rb > after.json

bin/deploy-check/compare.rb before.json after.json
```

`snapshot.rb` is strictly read-only. Non-zero exit means something in the
must-not-change set moved.

## Fails the check

A deploy should never change these on its own:

- `available_works` — a tenant's depositors gaining or losing work types
- `consortia`, `profile_path` — consortium membership, or which m3 profile resolves
- `themes`, `schema_classes`, `features`
- a tenant disappearing, newly erroring, or a sample work losing its thumbnail
- global registered work types, derivative labels, viewer and manifest config

Reported but not failed: counts, vocabulary term counts, schema version, Hyrax
and Puma versions, and any key the previous version could not report at all.

## Why `available_works` is the one to watch

`Site#available_works` is a persisted column seeded only when the Site row is
created (`Site.instance` uses `first_or_create`). Nothing recomputes it at boot
or during migration, so a deploy alone cannot change it — which is exactly why a
change there means something wrote to it.

The corollary: assigning `part_of_consortia` to an existing tenant does **not**
update its work types. Both have to be set. The snapshot records
`available_works` and `allowed_by_consortium` separately so the gap is visible.

## Not covered — check these by hand

- **Static assets.** Fetch the homepage and confirm the fingerprinted
  `/assets/application-*.css` and `.js` return 200. The nginx image bakes assets
  in at build time, so a bad build is an unstyled site, not an error.
- **Safari video.** New ingests produce only `thumbnail` and `mp4`; no webm fallback.
- **Migration duration.** `pg_trgm` builds a GIN index per tenant over
  `qa_local_authority_entries`; `bin/helm_deploy` runs with `--atomic --timeout 15m0s`.
- **Behaviour under load.**

## Baselines

`baselines/` holds the capture taken immediately before a production deploy, kept
only until that deploy is verified. A baseline's value is comparative, so once the
post-deploy diff is clean the old file is dead weight - prune it rather than
accumulating one per deploy.

`production-2026-08-25-pre-v7.2.0.json` is the state on Hyrax 5.2.0 / Puma 5.6.9
before the Hyku main bump, across all 37 tenants. Delete it once v7.2.0 is
verified in production.
