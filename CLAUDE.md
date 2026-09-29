# HykuUp Knapsack

## Deploying

The generic procedure (promotion, baseline, verify, publish) lives in the
[notch8/playbook](https://github.com/notch8/playbook) skills; install them with the playbook's
`bin/install-skills`. Repo-specific facts:

| Branch | Environment | kubectl context | Namespace |
| --- | --- | --- | --- |
| `main` | dev | `r2-friends` | `hykuup-knapsack-dev` |
| `staging` | staging | `r2-friends` | `hykuup-knapsack-staging` |
| `production` | production | `r2-besties` | `hykuup-knapsack-production` |

- A push to any of those branches deploys automatically once Build Test Lint passes. The Deploy
  workflow's manual dispatch is for ad-hoc deploys and rollbacks.
- Promotion is `main` -> `staging` -> `production` by merge-commit PR only, never squash.
- Production window: Tuesdays 1-5pm Pacific, never Friday. Another weekday is fine if agreed.
  Merging the `staging` -> `production` PR is the deploy, so merge it inside the window.
- Release tags are HykuUp's own `v1.x` line, not Hyku's. `lib/hyku_knapsack/version.rb` must equal
  the Hyku version in `hyrax-webapp`; CI fails when they differ.
- Needs a human:
  - capture the `/deploy-regression-check` baseline before merging a promotion PR, and diff after;
  - publish the release draft (a `-rc` prerelease from staging, the stable release from
    production), adding the Hyku SHA and Hyrax version to the body.
