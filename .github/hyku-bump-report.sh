#!/usr/bin/env bash
# Builds the Hyku bump report for a pull request and posts it as a comment, replacing the
# previous one. Run by .github/workflows/hyku-bump-report.yaml from the knapsack's base branch.
# Needs GH_TOKEN, GITHUB_REPOSITORY, PR, BASE_SHA and HEAD_SHA. With DRY_RUN=1 it prints the
# report instead of posting it; OLD_HYKU and NEW_HYKU then preview a bump with no pull request
# yet (run from the knapsack's root): DRY_RUN=1 PR=0 OLD_HYKU=<sha> NEW_HYKU=<sha> ...
set -euo pipefail

marker='<!-- hyku-bump-report -->'
old=${OLD_HYKU:-$(gh api "repos/$GITHUB_REPOSITORY/contents/hyrax-webapp?ref=$BASE_SHA" --jq .sha)}
new=${NEW_HYKU:-$(gh api "repos/$GITHUB_REPOSITORY/contents/hyrax-webapp?ref=$HEAD_SHA" --jq .sha)}
if [ "$old" = "$new" ]; then
  echo "hyrax-webapp is unchanged; nothing to report."
  exit 0
fi

work=$(mktemp -d)
git clone --quiet --filter=blob:none --no-checkout https://github.com/samvera/hyku.git "$work/hyku"
git -C "$work/hyku" fetch --quiet origin "$old" "$new"

# Pull requests a range of commits belongs to. Hyku and Hyrax merge some PRs with a merge
# commit and squash others, so look each commit up instead of parsing commit messages. Each line
# names the PR's author, without an @, so the report doesn't notify people outside Notch8.
prs_between() { # repo base head
  gh api "repos/$1/compare/$2...$3?per_page=250" --jq '.commits[].sha' |
    while read -r sha; do
      gh api "repos/$1/commits/$sha/pulls" \
        --jq '.[] | select(.merged_at) | "- \(.base.repo.full_name)#\(.number) \(.title) (by \(.user.login)) [\([.labels[].name] | join(", "))]"'
    done | sort -u | sed 's/ \[\]$//'
}

hyrax_rev() { # hyku sha
  git -C "$work/hyku" show "$1:Gemfile.lock" |
    awk '/remote: https:\/\/github.com\/samvera\/hyrax/ {f=1} f && /revision:/ {print $2; exit}'
}

compare_status=$(gh api "repos/samvera/hyku/compare/$old...$new" --jq .status)
hyku_prs=$(prs_between samvera/hyku "$old" "$new")
old_hyrax=$(hyrax_rev "$old" || true)
new_hyrax=$(hyrax_rev "$new" || true)
hyrax_prs=""
if [ -n "$old_hyrax" ] && [ -n "$new_hyrax" ] && [ "$old_hyrax" != "$new_hyrax" ]; then
  hyrax_prs=$(prs_between samvera/hyrax "$old_hyrax" "$new_hyrax")
fi

# Gem versions that move with the bump, from Hyku's Gemfile.lock: released gems by version, and
# gems Hyku takes from git (Hyrax, Bulkrax, ...) by revision.
lock_versions() { # hyku sha -> "name version" for released gems, platform builds folded together
  git -C "$work/hyku" show "$1:Gemfile.lock" | awk '/^GEM$/ {g=1; next} /^[A-Z]/ {g=0} g && /^    [^ ]+ \(/ {gsub(/[()]/, "", $2); sub(/-.*/, "", $2); print $1, $2}' | sort -u
}
lock_git() { # hyku sha -> "repo revision" for gems from git
  git -C "$work/hyku" show "$1:Gemfile.lock" | awk '/^GIT$/ {g=1} /^[A-Z]/ && !/^GIT$/ {g=0} g && /remote:/ {r=$2} g && /revision:/ {sub(/^https:\/\/github.com\//, "", r); sub(/\.git$/, "", r); print r, $2}' | sort -u
}
gems=$(join -a1 -a2 -e '(none)' -o 0,1.2,2.2 <(lock_versions "$old") <(lock_versions "$new") |
  awk '$2 != $3 {print "| " $1 " | " $2 " | " $3 " |"}')
# Gems that most often need knapsack work when they move; shown outside the collapsed list.
key_gems='^\| (rails|blacklight|blacklight_range_limit|bulkrax|valkyrie|iiif_print|active-fedora|qa|devise|sidekiq|good_job|solr_wrapper|rsolr|hydra-head|riiif) \|'
key_gem_rows=$(grep -E "$key_gems" <<< "$gems" || true)
other_gem_rows=$(grep -vE "$key_gems" <<< "$gems" || true)
git_gems=$(join -a1 -a2 -e '(none)' -o 0,1.2,2.2 <(lock_git "$old") <(lock_git "$new") |
  awk '$2 != $3 {printf "| %s | `%s` | `%s` | [compare](https://github.com/%s/compare/%s...%s) |\n", $1, substr($2,1,7), substr($3,1,7), $1, $2, $3}')

# The pull requests in this bump that changed one upstream file, with their authors, so each
# override below names who to ask. Bots (merge-downs, version bumps) are left out.
pr_lines() { # repo, then commit shas on stdin -> "repo#N (by author)", once each
  while read -r sha; do
    gh api "repos/$1/commits/$sha/pulls" \
      --jq '.[] | select(.merged_at and (.user.login | endswith("[bot]") | not)) | "\(.base.repo.full_name)#\(.number) (by \(.user.login))"'
  done | sort -u | paste -sd ',' - | sed 's/,/, /g'
}
changed_by() { # "hyku" path, or "hyrax" path
  if [ "$1" = hyku ]; then
    git -C "$work/hyku" log --format=%H "$old..$new" -- "$2" | pr_lines samvera/hyku
  else
    gh api "repos/samvera/hyrax/commits?sha=$new_hyrax&path=$2&per_page=100" --jq '.[].sha' |
      grep -Fxf "$work/hyrax_shas" | pr_lines samvera/hyrax
  fi
}
with_prs() { # text, prs
  if [ -n "$2" ]; then echo "$1: changed in $2"; else echo "$1"; fi
}

# Hyku files the bump changes that this knapsack replaces (same path) or decorates (a
# <name>_decorator.rb for the same file name).
overrides=""
while read -r path; do
  case "$path" in app/*|config/*|lib/*) ;; *) continue ;; esac
  prs=""
  if [ -e "$path" ]; then
    prs=$(changed_by hyku "$path")
    overrides+="$(with_prs "- \`$path\` (overridden: \`$path\`)" "$prs")"$'\n'
  fi
  name=$(basename "$path" .rb)
  while read -r decorator; do
    [ -n "$prs" ] || prs=$(changed_by hyku "$path")
    overrides+="$(with_prs "- \`$path\` (decorated: \`$decorator\`)" "$prs")"$'\n'
  done < <(find app lib -name "${name}_decorator.rb" 2>/dev/null)
done < <(git -C "$work/hyku" diff --name-only "$old" "$new")

# Hyrax files the Hyrax change touches that this knapsack decorates.
if [ -n "$hyrax_prs" ]; then
  gh api "repos/samvera/hyrax/compare/$old_hyrax...$new_hyrax?per_page=250" --jq '.commits[].sha' > "$work/hyrax_shas"
  while read -r path; do
    case "$path" in app/*|lib/*) ;; *) continue ;; esac
    name=$(basename "$path" .rb)
    while read -r decorator; do
      overrides+="$(with_prs "- Hyrax \`$path\` (decorated: \`$decorator\`)" "$(changed_by hyrax "$path")")"$'\n'
    done < <(find app lib -name "${name}_decorator.rb" 2>/dev/null)
  done < <(gh api "repos/samvera/hyrax/compare/$old_hyrax...$new_hyrax" --jq '.files[].filename')
fi

# Overrides waiting on an upstream fix this bump brings in. Knapsack code and open issues or PRs
# that name one of the bump's Hyku or Hyrax pull requests (e.g. "remove once Hyku includes
# samvera/hyku#3358") are cleanup candidates: the knapsack copy may no longer be needed.
cleanup=""
upstream=$(printf '%s\n%s\n' "$hyku_prs" "$hyrax_prs" | sed -nE 's/^- (samvera\/[a-z_-]+)#([0-9]+) .*/\1 \2/p')
if [ -n "$upstream" ]; then
  gh api --paginate "repos/$GITHUB_REPOSITORY/issues?state=open&per_page=100" \
    --jq '.[] | select(.number != '"$PR"') | "\(.number)\t\(.title)\t\(((.title + " " + (.body // "")) | gsub("[\\n\\t]"; " ")))"' > "$work/open.tsv"
  while read -r repo n; do
    by=$(printf '%s\n%s\n' "$hyku_prs" "$hyrax_prs" | grep -F -- "- $repo#$n " | sed -nE 's/.* \(by ([^)]+)\).*/ by \1/p' | head -1 || true)
    short=${repo#samvera/}
    # samvera/hyku#3358, github.com/samvera/hyku/pull/3358, or "Hyku #3358" / "Hyku PR #3358"
    pattern="($repo(#|/pull/|/issues/)$n|[Hh]${short:1} (PR )?#$n)([^0-9]|\$)"
    while IFS=$'\t' read -r m mtitle _; do
      cleanup+="- #$m $mtitle (mentions $repo#$n$by)"$'\n'
    done < <(grep -E "$pattern" "$work/open.tsv" || true)
    while IFS=: read -r file line _; do
      cleanup+="- \`$file:$line\` (mentions $repo#$n$by)"$'\n'
    done < <(grep -rnE "$pattern" app lib config spec 2>/dev/null || true)
  done <<< "$upstream"
fi

{
  echo "$marker"
  echo "### Hyku bump: \`${old::7}\` → \`${new::7}\`"
  echo
  echo "[Compare on GitHub](https://github.com/samvera/hyku/compare/$old...$new)"
  if [ "$compare_status" != "ahead" ]; then
    echo
    echo "**Warning:** \`${new::7}\` is not ahead of \`${old::7}\` (compare status: \`$compare_status\`). This may move Hyku backwards."
  fi
  echo
  if [ -n "$cleanup" ]; then
    echo "#### Overrides this bump may make unnecessary"
    echo
    echo "These name an upstream fix this bump brings in. Check whether the knapsack's copy can go, and remove it in this pull request:"
    echo
    printf '%s' "$cleanup" | sort -u
    echo
  fi
  echo "#### Hyku files this knapsack overrides or decorates"
  echo
  if [ -n "$overrides" ]; then
    echo "Check each still works with the new Hyku before merging. The PR that changed it, and its author, is who to ask; if it needs knapsack work, they add it to this pull request:"
    echo
    printf '%s' "$overrides" | sort -u
  else
    echo "None."
  fi
  echo
  echo "#### Hyku pull requests"
  echo
  echo "${hyku_prs:-None found.}"
  echo
  if [ -n "$hyrax_prs" ]; then
    echo "#### Hyrax pull requests (\`${old_hyrax::7}\` → \`${new_hyrax::7}\`)"
    echo
    echo "$hyrax_prs"
  else
    echo "Hyrax is unchanged."
  fi
  echo
  echo "#### Gem changes"
  echo
  if [ -n "$gems" ] || [ -n "$git_gems" ]; then
    if [ -n "$git_gems" ]; then
      echo "| From git | Before | After | |"
      echo "| --- | --- | --- | --- |"
      echo "$git_gems"
      echo
    fi
    if [ -n "$key_gem_rows" ]; then
      echo "| Gem | Before | After |"
      echo "| --- | --- | --- |"
      echo "$key_gem_rows"
      echo
    fi
    if [ -n "$other_gem_rows" ]; then
      echo "<details><summary>$(wc -l <<< "$other_gem_rows" | tr -d ' ') other gems change version</summary>"
      echo
      echo "| Gem | Before | After |"
      echo "| --- | --- | --- |"
      echo "$other_gem_rows"
      echo
      echo "</details>"
    fi
  else
    echo "No gem versions change."
  fi
  echo
  echo "If a change here needs work in this knapsack, add it to this pull request before merging, so they ship together."
} > "$work/report.md"

if [ "${DRY_RUN:-}" = 1 ]; then
  cat "$work/report.md"
  exit 0
fi

existing=$(gh api "repos/$GITHUB_REPOSITORY/issues/$PR/comments?per_page=100" \
  --jq "[.[] | select(.body | startswith(\"$marker\"))][0].id // empty")
if [ -n "$existing" ]; then
  gh api --method PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$existing" -F body=@"$work/report.md" > /dev/null
else
  gh api --method POST "repos/$GITHUB_REPOSITORY/issues/$PR/comments" -F body=@"$work/report.md" > /dev/null
fi
echo "Posted the report on #$PR."
