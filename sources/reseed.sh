#!/usr/bin/env bash
# Rebuild the whole recipe store from declarative sources INTO AN EMPTY STORE, e.g.:
#   BATCH_DB=/tmp/fresh/db.json bash reseed.sh
# Rebuilds: 30 ingredients, 4 root cookies/cheesecakes, the banana variant, the
# M3 frosting sub-recipe (extracted into Red Velvet), and the Cool-Whip frosting variant.
set -euo pipefail
BATCH=/Users/williamjin/Documents/batch/batch
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "seeding ingredients..."
while read -r ing; do echo "$ing" | "$BATCH" ingredient add >/dev/null; done < <(jq -c '.[]' "$DIR/ingredients.json")

echo "creating root recipes..."
for f in vanilla-pumpkin-cheesecake red-velvet-cookies birthday-cake-cookies lemon-protein-cookies protein-cream-cheese-frosting; do
  "$BATCH" create --file "$DIR/$f.json" >/dev/null && echo "  + $f"
done

echo "rebuilding banana variant..."
VF="$DIR/banana-cheesecake.variant.json"
BASE=$("$BATCH" list | jq -r '.[] | select(.name=="Vanilla Pumpkin Protein Cheesecake") | .headVersionId')
V=$("$BATCH" derive "$BASE" -n "$(jq -r .name "$VF")" | jq -r '.version.id')
while read -r entry; do V=$(echo "$entry" | "$BATCH" override "$V" -m "reseed override" | jq -r '.version.id'); done < <(jq -c '.overrides[]' "$VF")
echo "  + banana variant -> $V"

# --- M3 composition: extract Red Velvet's inline frosting into a sub-recipe, in place. ---
# The frosting root is created above (in the roots loop); here we re-point Red Velvet at it.
# The sub_recipe pin is resolved from the frosting's head BY NAME at apply time, so this
# survives a fresh reseed (new ids) — the same name-resolution trick the banana base uses.
echo "composing Red Velvet frosting (M3 in-place extraction)..."
CF="$DIR/red-velvet.compose-frosting.json"
FROST=$("$BATCH" list | jq -r '.[] | select(.name=="Protein Cream-Cheese Frosting") | .headVersionId')
RV=$("$BATCH" list | jq -r '.[] | select(.name=="Red Velvet Protein Cookies") | .headVersionId')
while read -r entry; do
  entry=$(echo "$entry" | jq -c --arg fid "$FROST" 'if (.payload.resolution.subRecipeRef != null) then .payload.resolution = {kind:"sub_recipe", subRecipeVersionId:$fid} else . end')
  RV=$(echo "$entry" | "$BATCH" override "$RV" -m "reseed: compose frosting" | jq -r '.version.id')
done < <(jq -c '.overrides[]' "$CF")
echo "  + Red Velvet composed -> $RV"

# --- M3 frosting base->variant tree: Cool-Whip frosting derived from the cream-cheese root. ---
echo "deriving Cool-Whip frosting variant..."
CW="$DIR/cool-whip-frosting.variant.json"
CWBASE=$("$BATCH" list | jq -r '.[] | select(.name=="Protein Cream-Cheese Frosting") | .headVersionId')
CWV=$("$BATCH" derive "$CWBASE" -n "$(jq -r .name "$CW")" | jq -r '.version.id')
while read -r entry; do CWV=$(echo "$entry" | "$BATCH" override "$CWV" -m "reseed: cool-whip" | jq -r '.version.id'); done < <(jq -c '.overrides[]' "$CW")
echo "  + Cool-Whip frosting variant -> $CWV"
