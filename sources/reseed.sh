#!/usr/bin/env bash
# Rebuild the whole recipe store from declarative sources INTO AN EMPTY STORE, e.g.:
#   BATCH_DB=/tmp/fresh/db.json bash reseed.sh
set -euo pipefail
BATCH=/Users/williamjin/Documents/batch/batch
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "seeding ingredients..."
while read -r ing; do echo "$ing" | "$BATCH" ingredient add >/dev/null; done < <(jq -c '.[]' "$DIR/ingredients.json")
echo "creating root recipes..."
for f in vanilla-pumpkin-cheesecake red-velvet-cookies birthday-cake-cookies lemon-protein-cookies; do
  "$BATCH" create --file "$DIR/$f.json" >/dev/null && echo "  + $f"
done
echo "rebuilding banana variant..."
VF="$DIR/banana-cheesecake.variant.json"
BASE=$("$BATCH" list | jq -r '.[] | select(.name=="Vanilla Pumpkin Protein Cheesecake") | .headVersionId')
V=$("$BATCH" derive "$BASE" -n "$(jq -r .name "$VF")" | jq -r '.version.id')
while read -r entry; do V=$(echo "$entry" | "$BATCH" override "$V" -m "reseed override" | jq -r '.version.id'); done < <(jq -c '.overrides[]' "$VF")
echo "  + banana variant -> $V"
