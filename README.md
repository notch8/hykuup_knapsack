<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [HykuKnapsack](#hykuknapsack)
  - [Introduction](#introduction)
    - [Version strategy](#version-strategy)
    - [Precedence](#precedence)
  - [Usage](#usage)
    - [Creating Your Knapsack](#creating-your-knapsack)
      - [New Repository](#new-repository)
      - [Fork on Github](#fork-on-github)
    - [Hyku and HykuKnapsack](#hyku-and-hykuknapsack)
    - [Overrides](#overrides)
    - [Deployment scripts](#deployment-scripts)
    - [Theme files](#theme-files)
    - [Gems](#gems)
  - [Features](#features)
    - [Consortium-Based Tenant Configuration](#consortium-based-tenant-configuration)
    - [Tenant-Specific Work Type Filtering](#tenant-specific-work-type-filtering)
    - [Dynamic Metadata Profile Loading](#dynamic-metadata-profile-loading)
  - [Converting a Fork of Hyku Prime to a Knapsack](#converting-a-fork-of-hyku-prime-to-a-knapsack)
  - [Using the Knapsacker Tool](#using-the-knapsacker-tool)
  - [Installation](#installation)
  - [Contributing](#contributing)
  - [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# HykuKnapsack

[Hyku Knapsack](https://github.com/samvera-labs/hyku_knapsack) is a little wrapper around Hyku to make development and deployment easier. Primary goals of this project
include making contributing back to the Hyku project easier and making upgrades a snap.

## Introduction

[Hyku](https://github.com/samvera/hyku) is a Rails application that leverages Rails Engines and other gems to provide functionality.  A Hyku Knapsack is also a Rails engine, but it integrates differently than other engines.

### Version strategy

Hyku Knapsack versions are aligned with [Hyku](https://github.com/samvera/hyku) versions: **Knapsack 6** works with the **Hyku 6** series, **Knapsack 7** with the **Hyku 7** series (which introduces breaking changes), and so on. That way you can tell at a glance which Knapsack release to use for a given Hyku version. Pick the Knapsack major version that matches your Hyku major version.

### Deploy regression checking

Pre- and post-deploy tenant snapshots live in the shared playbook rather than here, so one reviewed copy serves every knapsack instead of each repo carrying a fork:

```bash
ln -s ~/Work/playbook/skills/deploy-regression-check ~/.claude/skills/deploy-regression-check
```

That makes it available as `/deploy-regression-check`. See [notch8/playbook](https://github.com/notch8/playbook) `skills/deploy-regression-check/`, and the method write-up in `devops/deployments/regression-testing-a-deploy-with-claude.md`.

### Deploying to production

**Production deploys go out Tuesdays, 1pm-5pm Pacific, and never on a Friday.** The window can be moved to another weekday when there is reason to; Friday is out either way, because it leaves no working day to notice or fix fallout. Staging has no window.

`.github/workflows/deploy.yaml` is `workflow_dispatch` only. **Dispatch on the release tag, not on a branch** - a branch ref can move under you if someone merges mid-dispatch, and the image tag is derived from the ref's SHA.

The order is: capture the regression baseline immediately before dispatching, tag `origin/main` and push, dispatch Deploy with the tag as the ref, verify the rollout, then snapshot again and diff, and only then write the release notes. The release body makes client-facing claims about what is live, so it cannot honestly be written beforehand.

Releases are on HykuUp's own `v1.x` line and do not mirror Hyku's version. `lib/hyku_knapsack/version.rb` carries a separate `7.x` number tracking Hyku compatibility.

Full process, including the cluster contexts, rollback approach and the traps that have cost us, in [notch8/playbook](https://github.com/notch8/playbook) `skills/hykuup-production-deploy/`:

```bash
ln -s ~/Work/playbook/skills/hykuup-production-deploy ~/.claude/skills/hykuup-production-deploy
```

### Precedence

In a traditional setup, a Rails' application's views, translations, and code supsedes all other gems and engines.  However, we have setup Hyku Knapsack to have a higher load precedence than the underlying Hyku application.

The goal being that a Hyku Knapsack should make it easier to maintain, upgrade, and contribute fixes back to Hyku.

See [Overrides](#overrides) for more discussion on working with a Hyku Knapsack.


## Usage

### Creating Your Knapsack

In working on a Hyku Knapsack, you want to be able to track changes in the upstream knapsack as well as make local changes for your application.  Start by making a clone.  You can do this by:

- _Preferred_ Creating a [New Repository](#new-repository) and pushing your local clone
- Creating a [Fork on Github](#fork-on-github)

#### New Repository

In your Repository host of choice, create a new (and for now empty) repository.

- `$PROJECT_NAME` must only contain letters, numbers and underscores due to a bundler limitation.
- `$NEW_REPO_URL` is the location of your application's knapsack git project (e.g. https://github.com/my-org/my_org_knapsack)

```bash
git clone https://github.com/samvera-labs/hyku_knapsack $PROJECT_NAME_knapsack
cd $PROJECT_NAME_knapsack
git remote rename origin prime
git remote add origin $NEW_REPO_URL
git branch -M main
git push -u origin main
```

Naming the `samvera-labs/hyku_knapsack` as `prime` helps clarify what we mean.  In conversations about Hyku instances, invariably we use the language of Prime to reflect what's in Samvera's repositories.  By using that language for remotes, we help reinforce the concept that `https://github.com/samvera/hyku` is Hyku prime and `https://github.com/samvera-labs/hyku_knapsack` is Knapsack prime.

#### Fork on Github

If you choose to fork Knapsack, be aware that this will impact how you manage pull requests via Github.  Namely as you submit PRs on your Fork, the UI might default to applying that to the fork's origin (e.g. Knapsack upstream).

To ease synchronization of your Knapsack and Knapsack "prime", consider adding knapsack prime as a remote:

```bash
cd $PROJECT_NAME_knapsack
git remote add prime https://github.com/samvera-labs/hyku_knapsack
```

### Keeping Your Knapsack Updated with Prime

Whether you've set up your Knapsack using a new repository or a fork, you may want to pull in updates from `hyku_knapsack` prime (i.e., `https://github.com/samvera-labs/hyku_knapsack`) over time. To do this, ensure you've added the upstream remote as `prime`:

```bash
git remote add prime https://github.com/samvera-labs/hyku_knapsack
```

To fetch and merge in changes from the prime repository:

```bash
git fetch prime
git merge prime/main
```

If you prefer a cleaner commit history, you may rebase instead:

```bash
git fetch prime
git rebase prime/main
```

After resolving any conflicts, push the updates to your repository:

```bash
git push origin main
```

This setup ensures your Knapsack stays aligned with ongoing improvements and bug fixes in the Hyku Knapsack project.


### Hyku and HykuKnapsack

You run your Hyku application by way of the HykuKnapsack.  As mentioned, the HykuKnapsack contains your application's relevant information for running an instance of Hyku.

There are two things you need to do:

- Ensure you have the [reserved branch](#reserved-branch)
- Initialize the [Hyku submodule](#hyku-submodule)

#### Reserved Branch

Knapsack turns the assumptions of a Rails engine upside-down; the application overlays traditional engines, but Knapsack overlays the application.  As such the Gemfile declared in Hyku does some bundler trickery.

In the `$PROJECT_NAME_knapsack` directory, you need to run the following:

```bash
git fetch prime
git checkout prime/required_for_knapsack_instances
git switch -c required_for_knapsack_instances
```

For Hyku to build with Knapsack, we need a local branch named `required_for_knapsack_instances`.  _Note:_ As we work more with Knapsack maintenance there may be improvements to this shim.

#### Hyku Submodule

A newly cloned knapsack will have an empty `./hyrax-webapp` directory.  That is where the Hyku application will exist.  The version of Hyku is managed via a [Git submodule](https://git-scm.com/docs/git-submodule).

To bring that application into your knapsack, you will need to initialize the Hyku submodule:

```bash
❯ git submodule init
Submodule 'hyrax-webapp' (https://github.com/samvera/hyku.git) registered for path 'hyrax-webapp'
```

Then update the submodule to clone the remote Hyku repository into `./hyrax-webapp`.  The `KNAPSACK-SPECIFIED-HYKU-REPOSITORY-SHA` is managed within the Hyku Knapsack (via Git submodules).

```bash
❯ git submodule update
Cloning into '/path/to/$PROJECT_NAME_knapsack/hyrax-webapp'...
Submodule path 'hyrax-webapp': checked out '<KNAPSACK-SPECIFIED-HYKU-REPOSITORY-SHA>'
```

The configuration of the submodule can be found in the `./.gitmodules` file.  During development, we've specified the submodule's branch (via `git submodule set-branch --branch <NAME> -- ./hyrax-webapp`).

Below is an example of our Adventist Knapsack submodule.

```
❯ cat .gitmodules
[submodule "hyrax-webapp"]
	path = hyrax-webapp
	url = https://github.com/samvera/hyku.git
	branch = adventist_dev
```

When you want to bring down an updated version of your Hyku submodule, use the following:

```bash
> git submodule update --remote
```

This will checkout the submodule to the HEAD of the specified branch.

### 🚀 Getting Started with Stack Car

Hyku Knapsack uses [Stack Car](https://github.com/notch8/stack_car) to manage Docker-based development.
For alternative setup options, refer to [Hyku's Getting Started](https://github.com/samvera/hyku/blob/main/docs/getting-started.md).

> **Important:** All commands below should be run from the **root of your Knapsack project**, **not** from within the `hyrax-webapp` submodule.

#### 1. Install Stack Car (if you haven't already)

```bash
gem install stack_car
```

#### 2. Set up the development proxy

You only need to run this once per installed version of Stack Car:

```bash
sc proxy cert
sc proxy up
```

#### 3. Prepare and start the stack

```bash
sc pull     # Pull the latest base images
sc build    # Build your local image
sc up       # Start the container stack
```

#### 4. Open the app in your browser

Once running, visit:

```
https://admin-{repo-name}.localhost.direct/
```

Example (for the Hyku Knapsack repo):

```
https://admin-hyku-knapsack.localhost.direct/
```

#### 5. Open a shell in the container (if needed)

```bash
sc sh
```

### Overrides

Before overriding anything, please think hard (or ask the community) about whether what you are working on is a bug or feature that can apply to Hyku itself. If it is, please make a branch in your Hyku checkout (`./hyrax-webapp`) and do the work there. Read more about [working with Hyku branches in your Knapsack](https://github.com/samvera-labs/hyku_knapsack/wiki/Hyku-Branches).

Adding decorators to override features is fairly simple. We do recommend some [best practices](https://github.com/samvera-labs/hyku_knapsack/wiki/Decorators-and-Overrides).

Any file with `_decorator.rb` in the app or lib directory will automatically be loaded along with any classes in the app directory.

### Deployment scripts

Deployment code can be added as needed. For the production deploy process itself, see [Deploying to production](#deploying-to-production).

### Theme files

Theme files (views, css, etc) can be added to the knapsack. We recommend adding an [override comment](https://github.com/samvera-labs/hyku_knapsack/wiki/Decorators-and-Overrides#best-practices-for-view-overrides)

### Gems

It can be useful to add additional gems to the bundle. This can be done w/o editing Hyku by adding them to the [./bundler.d/example.rb](./bundler.d/example.rb].  [See the bundler-inject documentation for more details](https://github.com/kbrock/bundler-inject/) on overriding and adding gems.

**NOTE:** Do not add gems to the gemspec nor Gemfile.  When you add to the knapsack Gemfile/gemspec, when you bundle, you'll update the Hyku Gemfile; which will mean you might be updating Hyku prime with knapsack installation specific dependencies.  Instead add gems to `./bundler.d/example.rb`.

### Work Resource Generator

This project includes a Rails generator to create new custom work types within your Hyku Knapsack application. This generator is a modified version of the one provided by Hyrax, specifically adapted to ensure that all generated files are created within the knapsack directory structure, rather than in the core Hyku submodule.

To use the generator, run the following command from the root of your knapsack project:

```bash
bundle exec rails generate hyku_knapsack:work_resource WorkType
```
Replace `WorkType` with the desired name for your new work type. The generator will create the necessary model, controller, form, indexer, and view files in the appropriate directories within the knapsack.

## Features

This HykuKnapsack includes several custom features for consortium-based multitenancy:

### Consortium-Based Tenant Configuration

This knapsack overrides Hyku's default profile loading behavior. Instead of all tenants using the same default metadata profile, tenants can now have their own consortium-specific default profiles based on their `part_of_consortia` setting.

**Configuration:**
- Consortium definitions are stored in `config/consortia.yml`
- Admin interface allows setting `part_of_consortia` field on accounts
- Supports flexible consortium management without code changes

### Tenant-Specific Work Type Filtering

Each tenant only sees work types appropriate for their consortium membership:

- **Mobius Consortium**: Excludes `ScholarlyWork`
- **Generic tenants**: Excludes all tenant-specific work types

**Implementation:**
- Work type filtering applied to admin dashboard, work creation dropdowns, and all work type selection interfaces
- Uses `TenantWorkTypeFilter` service for consistent filtering logic
- Automatically updates `Site.instance.available_works` based on tenant consortium

### Dynamic Metadata Profile Loading

Default metadata profiles are automatically selected based on tenant consortium membership:

- **Mobius Consortium**: Loads `config/metadata_profiles/mobius/m3_profile.yaml`
- **Generic tenants**: Loads `config/metadata_profiles/default/m3_profile.yaml`

**Management:**
- Use `rake hykuup:profiles:add_tenant_profiles` to add profiles for all tenants (preserves existing)
- Use `rake hykuup:profiles:add_consortium_profiles[consortium]` to add profiles for a specific consortium
- Use `rake hykuup:profiles:add_tenant_profile[tenant]` to add profile for a specific tenant
- Use `rake hykuup:profiles:reset_all` to reset all tenant profiles (DESTRUCTIVE)
- Use `rake hykuup:profiles:reset_tenant[tenant_name]` to reset a specific tenant (DESTRUCTIVE)
- Profile upload validation prevents incompatible work types

**Rake Task Examples:**
```bash
# Safe operations (preserve existing profiles)
rake hykuup:profiles:add_tenant_profiles                   # All tenants
rake hykuup:profiles:add_consortium_profiles[unca]         # All tenants in UNCA consortium only
rake hykuup:profiles:add_consortium_profiles[mobius]       # All tenants in Mobius consortium only
rake hykuup:profiles:add_tenant_profile[demo]              # Specific tenant

# Destructive operations (overwrite existing profiles)
rake hykuup:profiles:reset_all                             # All tenants
rake hykuup:profiles:reset_tenant[demo]                    # Specific tenant
```

### Public demo tenants

A tenant flagged `public_demo_tenant` resets itself nightly to a stored **golden snapshot**, so a publicly writable demo recovers from whatever visitors did to it. `sandbox.hykuup.com` is the only one in production.

The reset does three different things to three categories, and the third is the one that surprises people:

| Category | What the nightly reset does |
|---|---|
| In the snapshot: the `Site` row, all content blocks, featured works | **Overwritten** with the captured values |
| Deposited content: works, file sets, collections, Bulkrax importers and exporters | **Destroyed**, then the seed corpus is re-imported |
| Everything else: metadata profile, feature flags, collection types, and **account settings** | **Untouched**, so a change there is permanent |

Note that collections *are* destroyed and re-seeded; collection *types*, being configuration, are not.

**To make a change survive the reset, retake the snapshot.** Appearance settings and page copy live in the `Site` row and in content blocks, so they are restored from the snapshot every night. Editing them through the admin UI without retaking the snapshot means the change is reverted at the next reset, with no error and nothing in the logs. The demo password lives in the `marketing_text` content block, so it has the same problem.

```bash
bundle exec rails "hyku:demo:snapshot[sandbox.hykuup.com]"   # capture current state as golden
bundle exec rails "hyku:demo:reset[sandbox.hykuup.com]"      # force a reset (DESTRUCTIVE)
```

Quote the task name; an unquoted `[...]` is a glob in zsh. The tenant argument is required and accepts a cname or an account name.

`snapshot!` captures current state wholesale, not just the field you changed, so anything else that has drifted is promoted to permanent at the same time. Check the tenant looks right before running it.

**Do not retake the snapshot to recover from vandalism.** `accounts.demo_tenant_snapshot` is a single column overwritten in place with no history, so retaking it after someone has damaged the tenant destroys the known-good state permanently.

`Site#contact_email` is a `sites` column and therefore reverts, while `Account#contact_email_to`, which is where the contact form actually mails, is an account setting and never reverts. Two similarly named fields, opposite behaviour.

**Configuration** comes from the environment, set in `ops/production-deploy.tmpl.yaml`: `DEMO_SEED_CSV_PATH` (a `%{tenant}` placeholder expands to the account name), `DEMO_KEEP_USERS`, `DEMO_IMPORT_USER`, `DEMO_HEALTH_CHECK`. There is no cron: `Account#find_or_schedule_jobs` plants `DemoTenantResetJob` and each successful run re-enqueues itself for the next day.

The full operational guide, including how to check the nightly chain is actually succeeding, is in [notch8/playbook](https://github.com/notch8/playbook) `skills/demo-tenant-snapshot/`:

```bash
ln -s ~/Work/playbook/skills/demo-tenant-snapshot ~/.claude/skills/demo-tenant-snapshot
```

**Known gaps.** The third row of that table is a defect rather than a design decision: the published demo admin login can change those settings and nothing restores them (#760). Uploads are also uncapped (#752), the reset never reclaims stored files (#761), and the "nightly" reset fires at 17:00 Pacific because `Date.tomorrow.midnight` is evaluated in a UTC application (#751).

## Adding New Consortia

<details>
<summary>Click to expand: How to add a new consortium to the system</summary>

To add a new consortium to the system, follow these steps:

### 1. Define the Consortium

Add your consortium to `config/consortia.yml` with its excluded work types:

```yaml
- name: "UNCA Consortium"
  identifier: "unca"
  excluded_work_types:
    - "MobiusWork"
- name: "Mobius Consortium"
  identifier: "mobius"
  excluded_work_types:
    - "ScholarlyWork"
- name: "Your New Consortium"
  identifier: "your_consortium"
  excluded_work_types:
    - "SomeWorkType"
    - "AnotherWorkType"
```

### 2. Create Consortium-Specific Profile

Create a metadata profile for your consortium at `config/metadata_profiles/your_consortium/m3_profile.yaml`. You can copy the default profile and modify it as needed:

```bash
mkdir -p config/metadata_profiles/your_consortium
cp config/metadata_profiles/default/m3_profile.yaml config/metadata_profiles/your_consortium/m3_profile.yaml
```

### 3. Update Rake Tasks (Optional)

If you want to include your consortium in the bulk operations, update `lib/tasks/hyku_knapsack_tasks.rake`:

```ruby
# Add a new namespace for your consortium
namespace :your_consortium do
  desc 'Update Bulkrax field mappings across all Your Consortium tenants'
  task update_field_mappings: :environment do
    your_consortium_tenants = Account.where(part_of_consortia: 'your_consortium')
    # ... your consortium-specific logic
  end
end
```

### 4. Test Your Changes

After making these changes:

1. Run the profile reset rake task to test profile loading
2. Create a test account with your consortium setting
3. Verify work type filtering works correctly
4. Test profile loading in the admin interface

**Note:** The system will automatically pick up new consortium definitions from the YAML file without requiring a restart. No code changes are needed!

</details>

## Converting a Fork of Hyku Prime to a Knapsack

Prior to Hyku Knapsack, organizations would likely clone [Hyku](https://github.com/samvera/hyku) and begin changing the code to reflect their specific needs.  The result was that the clone would often drift away from Samvera Hyku version.  This drift created challenges in reconciling what you had changed locally as well as how you could easily contribute some of your changes upstream to Samvera's Hyku.

With Hyku Knapsack, the goal is three-fold:

1. To isolate the upstream Samvera Hyku code from your local modifications.  This isolation is via the `./hyrax-webapp` submodule.
2. To provide a clear and separate space for extending/overriding Hyku functionality.
3. To provide a cleaner pathway for upgrading the underlying Hyku application; for things such as security updates, bug fixes, and upstream enhancements.

From those goals, we can begin to see what we want in our Hyku Knapsack:

1. Files that are not found in Hyku
2. Or files that are different from what is in Hyku (and thus will be loaded at a higher precedence)

Assuming you're working from a fork of Samvera's Hyku repository, these are some general steps.  First clone the Hyku Knapsack ([see the Usage section](#usage)).  You'll also want to initialize the git submodule.  Point the `./hyrax-webapp` to the branch/SHA of Samvera's Hyku that you want to use; **Note:** that version must include a `gem 'hyku_knapsack'` declaration (e.g. introduced in  [7853fe5d](https://github.com/samvera/hyku/blob/7853fe5d79afd9d90cec3b9ef666681b287ef4d0/Gemfile)).

You'll also want to have a local copy of your Hyku application.

You can then use `bin/knapsacker` to generate a list of files that need review.  That will give you a list of:

- Files in your Hyku that are exact duplicates of upstream Hyku file (prefix with `=`)
- Files that are in your Hyku but not in upstream Hyku (prefixed with `+`)
- Files that are changed in your Hyku relative to upstream Hyku (prefix with `Δ`)

You can pipe that output into a file and begin working on reviewing and moving files into the Knapsack.  This is not an easy to automate task, after all we're paying down considerable tech debt.

Once you've moved over the files, you'll want to boot up your Knapsack and then work through your test plan.

The `bin/knapsacker` is general purpose.  I have used it to compare one non-Knapsack Hyku instance against Samvera's Hyku.  I have also used it to compare a Knapsack's file against it's submodule Hyku instance.

## Using the Knapsacker Tool

The `bin/knapsacker` tool is a powerful utility for comparing files between different Hyku repositories. It helps identify which files are duplicates, which are unique, and which have been modified - making it easier to migrate from a traditional Hyku fork to a Knapsack structure or compare your Knapsack against upstream changes.

### Basic Usage

```bash
bin/knapsacker -y <your-directory> -u <upstream-directory>
```

#### Parameters

- `-y` (yours): Path to your Hyku repository or the directory you want to compare
- `-u` (upstream): Path to the upstream/reference repository to compare against

### Common Use Cases

#### 1. Comparing Your Hyku Fork Against Knapsack Prime
If you have an existing Hyku fork and want to see what needs to be moved to a Knapsack:

```bash
bin/knapsacker -y /path/to/your-hyku-fork -u .
```

#### 2. Comparing Your Knapsack Against Its Hyku Submodule
To see what files in your Knapsack differ from the underlying Hyku application:

```bash
bin/knapsacker -y . -u ./hyrax-webapp
```

#### 3. Comparing Any Two Hyku Repositories
```bash
bin/knapsacker -y /path/to/repo-a -u /path/to/repo-b
```

### Understanding the Output

The knapsacker generates three categories of files:

#### Files with `=` prefix
**exact duplicates** - Files in "yours" that are identical to "upstream" files. These typically don't need to be in your Knapsack since they're already provided by the base Hyku application.

#### Files with `+` prefix  
**unique to yours** - Files that exist in your repository but not in upstream. These are candidates for inclusion in your Knapsack as they represent custom functionality.

#### Files with `Δ` prefix
**modified files** - Files that exist in both repositories but have different content. These need review to determine if the changes should be moved to your Knapsack.

### Example Output

```
------------------------------------------------------------------------
Knapsacker run context:
------------------------------------------------------------------------
- Working Directory: /Users/example/hyku_knapsack
- Your Dir: /path/to/your-hyku
- Upstream Dir: .
- Patterns to Check:
  - spec/**/*.*
  - app/**/*.*
  - lib/**/*.*

------------------------------------------------------------------
Files in "yours" that are exact duplicates of "upstream" files
They are prefixed with a `='
------------------------------------------------------------------

----------------------------------------------------
Files that are in "yours" but not in "upstream" 
They are prefixed with a `+'
----------------------------------------------------
+ app/models/custom_work.rb
+ app/controllers/custom_controller.rb
+ lib/custom_service.rb

-------------------------------------------------------------
Files that are changed in "yours" relative to "upstream"
They are prefixed with a `Δ'
-------------------------------------------------------------
Δ config/application.rb
Δ app/models/user.rb
```

### Migration Workflow

1. **Run the comparison**: Use knapsacker to generate the file comparison
2. **Review `+` files**: These likely need to be copied to your Knapsack
3. **Analyze `Δ` files**: Determine which changes are customizations vs. bug fixes
   - Bug fixes should ideally be contributed back to Hyku prime
   - Customizations should be moved to your Knapsack as decorators/overrides
4. **Ignore `=` files**: These don't need to be in your Knapsack

### Tips

- **Pipe output to a file** for easier review: `bin/knapsacker -y ../your-hyku -u . > comparison.txt`
- **Focus on meaningful changes**: Not all `Δ` files need to be moved - some differences might be configuration or environment-specific
- **Use decorators when possible**: Instead of wholesale file replacement, consider using Rails decorators for modifications. See [best practices](https://github.com/samvera-labs/hyku_knapsack/wiki/Decorators-and-Overrides)
- **Test thoroughly**: After migration, ensure your Knapsack works correctly with your changes

## Installation

If not using a current version, add this line to Hyku's Gemfile:

```ruby
gem "hyku_knapsack", github: 'samvera-labs/hyku_knapsack', branch: 'main'
```

And then execute:
```bash
$ bundle
```

## Contributing

Contribution directions go here.

## License

The gem is available as open source under the terms of the [Apache 2.0](https://opensource.org/license/apache-2-0/).
