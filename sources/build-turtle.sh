#!/usr/bin/env bash
# Build the Turtle Protein Cheesecake:
#   3 sub-recipes (protein caramel swirl, real brown-sugar caramel, dark-choc ganache)
#   + a derive-off-the-base-cheesecake variant with crust / swirl / topping overrides.
# Sub-recipe pins are resolved BY NAME at apply time (survives a fresh reseed / new ids).
# Idempotent on the sub-recipes; re-running derives a fresh turtle chain.
set -euo pipefail
B=/Users/williamjin/Documents/batch/batch
DIR="$(cd "$(dirname "$0")" && pwd)"
byname() { "$B" list | jq -r --arg n "$1" '.[] | select(.name==$n) | .headVersionId'; }

echo "creating turtle sub-recipes..."
for f in turtle-caramel-swirl turtle-real-caramel turtle-ganache; do
  name=$(jq -r .name "$DIR/$f.json")
  if [ -z "$(byname "$name")" ]; then
    "$B" create --file "$DIR/$f.json" >/dev/null && echo "  + $name"
  else
    echo "  = $name (exists)"
  fi
done

VF="$DIR/turtle.variant.json"
BASE=$(byname "Vanilla Pumpkin Protein Cheesecake")
echo "deriving turtle off base cheesecake $BASE ..."
V=$("$B" derive "$BASE" -n "$(jq -r .name "$VF")" | jq -r '.version.id')

while read -r entry; do
  ref=$(echo "$entry" | jq -r '.payload.resolution.subRecipeRef // empty')
  if [ -n "$ref" ]; then
    fid=$(byname "$ref")
    entry=$(echo "$entry" | jq -c --arg fid "$fid" '.payload.resolution={kind:"sub_recipe",subRecipeVersionId:$fid}')
  fi
  V=$(echo "$entry" | "$B" override "$V" -m "turtle build" | jq -r '.version.id')
done < <(jq -c '.overrides[]' "$VF")

V=$("$B" edit "$V" -d "$(jq -r .description "$VF")" -t "$(jq -r '.tags|join(",")' "$VF")" | jq -r '.version.id')
echo "$V" > "$DIR/.turtle-head"
echo "turtle head -> $V"
