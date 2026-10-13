#!/usr/bin/env bash
# Builds the Hyku bump report for a pull request and posts it as a comment, replacing the
# previous one. Run by .github/workflows/hyku-bump-report.yaml from the knapsack's base branch.
# Needs GH_TOKEN, GITHUB_REPOSITORY, PR, BASE_SHA and HEAD_SHA. With DRY_RUN=1 it prints the
# report instead of posting it.
set -euo pipefail

marker='<!-- hyku-bump-report -->'
old=$(gh api "repos/$GITHUB_REPOSITORY/contents/hyrax-webapp?ref=$BASE_SHA" --jq .sha)
new=$(gh api "repos/$GITHUB_REPOSITORY/contents/hyrax-webapp?ref=$HEAD_SHA" --jq .sha)
if [ "$old" = "$new" ]; then
  echo "hyrax-webapp is unchanged; nothing to report."
  exit 0
fi

work=$(mktemp -d)
git clone --quiet --filter=blob:none --no-checkout https://github.com/samvera/hyku.git "$work/hyku"
git -C "$work/hyku" fetch --quiet origin "$old" "$new"

# Pull requests a range of commits belongs to. Hyku and Hyrax merge some PRs with a merge
# commit and squash others, so look each commit up instead of parsing commit messages.
prs_between() { # repo base head
  gh api "repos/$1/compare/$2...$3?per_page=250" --jq '.commits[].sha' |
    while read -r sha; do
      gh api "repos/$1/commits/$sha/pulls" \
        --jq '.[] | select(.merged_at) | "- \(.base.repo.full_name)#\(.number) \(.title) [\([.labels[].name] | join(", "))]"'
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

# Hyku files the bump changes that this knapsack replaces (same path) or decorates (a
# <name>_decorator.rb for the same file name).
overrides=""
while read -r path; do
  case "$path" in app/*|config/*|lib/*) ;; *) continue ;; esac
  if [ -e "$path" ]; then
    overrides+="- \`$path\` (overridden: \`$path\`)"$'\n'
  fi
  name=$(basename "$path" .rb)
  while read -r decorator; do
    overrides+="- \`$path\` (decorated: \`$decorator\`)"$'\n'
  done < <(find app lib -name "${name}_decorator.rb" 2>/dev/null)
done < <(git -C "$work/hyku" diff --name-only "$old" "$new")

# Hyrax files the Hyrax change touches that this knapsack decorates.
if [ -n "$hyrax_prs" ]; then
  while read -r path; do
    case "$path" in app/*|lib/*) ;; *) continue ;; esac
    name=$(basename "$path" .rb)
    while read -r decorator; do
      overrides+="- Hyrax \`$path\` (decorated: \`$decorator\`)"$'\n'
    done < <(find app lib -name "${name}_decorator.rb" 2>/dev/null)
  done < <(gh api "repos/samvera/hyrax/compare/$old_hyrax...$new_hyrax" --jq '.files[].filename')
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
  echo "#### Hyku files this knapsack overrides or decorates"
  echo
  if [ -n "$overrides" ]; then
    echo "Check each still works with the new Hyku before merging:"
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
