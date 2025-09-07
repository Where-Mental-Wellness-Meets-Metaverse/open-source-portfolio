#!/usr/bin/env bash
set -euo pipefail

PR_URL="${1:-}"
if [[ -z "$PR_URL" ]]; then
  echo "usage: scripts/update.sh <github_pr_url>"
  exit 1
fi

owner_repo="$(printf "%s" "$PR_URL" | awk -F'https://github.com/|/pull/' '{print $2}' | cut -d/ -f1-2)"
pr_number="$(printf "%s" "$PR_URL" | awk -F'/pull/' '{print $2}' | cut -d/ -f1)"
if [[ -z "$owner_repo" || -z "$pr_number" ]]; then
  echo "invalid PR url"
  exit 1
fi

declare -A MAP
MAP["ethereum/EIPs"]="blockchain-defi/ethereum-eips"
MAP["Uniswap/v3-core"]="blockchain-defi/uniswap-v3-core"
MAP["balancer/balancer-v2-monorepo"]="blockchain-defi/balancer-v2"
MAP["cosmos/cosmos-sdk"]="blockchain-defi/cosmos-sdk"
MAP["OpenZeppelin/openzeppelin-contracts"]="blockchain-defi/openzeppelin-contracts"
MAP["openmrs/openmrs-module-fhir2"]="healthcare-interoperability/openmrs-fhir2"
MAP["openmrs/openmrs-core"]="healthcare-interoperability/openmrs-core"
MAP["synthetichealth/synthea"]="healthcare-interoperability/synthea"
MAP["medibloc/panacea-core"]="healthcare-interoperability/panacea-core"
MAP["medblocks/medblocks-ui"]="healthcare-interoperability/medblocks-ui"
MAP["decentralized-identity/presentation-exchange"]="identity-standards/presentation-exchange"
MAP["bcgov/aries-vcr"]="identity-standards/aries-vcr"
MAP["zkpstandard/zkreference"]="identity-standards/zkreference"

dest="${MAP[$owner_repo]:-misc/${owner_repo//\//-}}"
mkdir -p "$dest"

patch_path="$dest/PR-$pr_number.patch"
notes_path="$dest/NOTES.md"
contrib="CONTRIBUTIONS.md"

curl -fsSL "${PR_URL}.patch" -o "$patch_path"

if [[ ! -f "$notes_path" ]]; then
  {
    echo "# $(basename "$dest")"
    echo "Upstream PR: $PR_URL"
  } > "$notes_path"
else
  if ! grep -q "$PR_URL" "$notes_path"; then
    echo "Upstream PR: $PR_URL" >> "$notes_path"
  fi
fi

title="$(gh pr view "$PR_URL" --json title --jq .title || echo "PR $pr_number")"
state="$(gh pr view "$PR_URL" --json state --jq .state || echo "UNKNOWN")"
section=""
case "$dest" in
  blockchain-defi/*) section="## Blockchain & DeFi" ;;
  healthcare-interoperability/*) section="## Healthcare & Interoperability" ;;
  identity-standards/*) section="## Identity & Standards" ;;
  *) section="## Misc" ;;
esac

if [[ ! -f "$contrib" ]]; then
  {
    echo "# Contribution Log"
    echo
    echo "## Blockchain & DeFi"
    echo
    echo "## Healthcare & Interoperability"
    echo
    echo "## Identity & Standards"
    echo
    echo "## Misc"
    echo
  } > "$contrib"
fi

tmp="$(mktemp)"
awk -v sec="$section" -v line="- ${owner_repo} PR #${pr_number} — status: ${state} — ${title}" '
  $0==sec && !found { print; print line; found=1; next }
  { print }
  END { if (!found) { print sec; print line } }
' "$contrib" > "$tmp"
mv "$tmp" "$contrib"

git add "$patch_path" "$notes_path" "$contrib"
git commit -m "chore: import ${owner_repo} PR #${pr_number} (${state})"
