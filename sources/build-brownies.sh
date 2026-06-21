#!/usr/bin/env bash
# Build the Protein Brownie family: Fudgy base + two derived texture variants
# (Fudgy+Chewy, Chewiest). Variant overrides are the full base->variant diff
# (auto-generated). Run once after a fresh reseed; re-running derives fresh chains.
set -euo pipefail
B=/Users/williamjin/Documents/batch/batch
DIR="$(cd "$(dirname "$0")" && pwd)"
byname() { "$B" list | jq -r --arg n "$1" '.[] | select(.name==$n) | .headVersionId'; }

# --- base ---
BNAME="Fudgy Protein Brownies"
if [ -z "$(byname "$BNAME")" ]; then
  "$B" create --file "$DIR/protein-brownies-fudgy.json" >/dev/null && echo "+ base: $BNAME"
else
  echo "= base exists: $BNAME"
fi

# --- variants ---
for VF in protein-brownies-fudgy-chewy protein-brownies-chewiest; do
  F="$DIR/$VF.variant.json"
  NAME=$(jq -r .name "$F")
  BASE=$(byname "$(jq -r .deriveFromRecipe "$F")")
  V=$("$B" derive "$BASE" -n "$NAME" | jq -r '.version.id')
  while read -r entry; do
    V=$(echo "$entry" | "$B" override "$V" -m "brownie variant build" | jq -r '.version.id')
  done < <(jq -c '.overrides[]' "$F")
  V=$("$B" edit "$V" -d "$(jq -r .description "$F")" -t "$(jq -r '.tags|join(",")' "$F")" | jq -r '.version.id')
  echo "+ variant: $NAME -> $V"
done
