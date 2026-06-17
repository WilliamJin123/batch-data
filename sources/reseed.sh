#!/usr/bin/env bash
# Rebuild the WHOLE recipe store from declarative sources INTO AN EMPTY STORE, e.g.:
#   BATCH_DB=/tmp/fresh/db.json bash reseed.sh
#
# Rebuilds, in dependency order: the ingredient library -> all root recipes ->
# every variant (derive off its base + replay its override manifest) -> the Red Velvet
# frosting composition -> the Turtle cheesecake (delegated to build-turtle.sh) -> the
# full tasting-feedback log. Bases/sub-recipes are resolved BY NAME at apply time, so the
# rebuild is deterministic even though version ids regenerate on every run.
#
# Note: Birthday Cake / Lemon / Lucky Charms are the CRUMBL-BASE variants (derived off
# "Crumbl Base Protein Cookie"); the older standalone roots they replaced are retired.
set -euo pipefail
BATCH=/Users/williamjin/Documents/batch/batch
DIR="$(cd "$(dirname "$0")" && pwd)"
byname() { "$BATCH" list | jq -r --arg n "$1" '.[] | select(.name==$n) | .headVersionId'; }

# build_variant <manifest.json> <baseVersionId> -> echoes the new head version id.
# Derives a variant off the base, replays the override manifest (re-pinning any
# {subRecipeRef:"<name>"} resolution to that recipe's current head), then applies metadata.
build_variant() {
  local vf="$1" base="$2" name v ref fid tags desc entry
  name=$(jq -r '.name' "$vf")
  v=$("$BATCH" derive "$base" -n "$name" | jq -r '.version.id')
  while read -r entry; do
    ref=$(echo "$entry" | jq -r '.payload.resolution.subRecipeRef // empty')
    if [ -n "$ref" ]; then
      fid=$(byname "$ref")
      entry=$(echo "$entry" | jq -c --arg fid "$fid" '.payload.resolution={kind:"sub_recipe",subRecipeVersionId:$fid}')
    fi
    v=$(echo "$entry" | "$BATCH" override "$v" -m "reseed: $name" | jq -r '.version.id')
  done < <(jq -c '.overrides[]' "$vf")
  desc=$(jq -r '.description // empty' "$vf")
  tags=$(jq -r 'if .tags then (.tags|join(",")) else empty end' "$vf")
  if   [ -n "$desc" ] && [ -n "$tags" ]; then v=$("$BATCH" edit "$v" -d "$desc" -t "$tags" | jq -r '.version.id')
  elif [ -n "$desc" ];                   then v=$("$BATCH" edit "$v" -d "$desc"          | jq -r '.version.id')
  elif [ -n "$tags" ];                   then v=$("$BATCH" edit "$v" -t "$tags"          | jq -r '.version.id')
  fi
  echo "$v"
}

echo "seeding ingredients..."
while read -r ing; do echo "$ing" | "$BATCH" ingredient add >/dev/null; done < <(jq -c '.[]' "$DIR/ingredients.json")

echo "creating root recipes..."
mkroot() { "$BATCH" create --file "$DIR/$1.json" | jq -r '.version.id'; }
VP=$(mkroot vanilla-pumpkin-cheesecake);            echo "  + Vanilla Pumpkin Cheesecake"
CRUMBL=$(mkroot crumbl-base-cookie);                echo "  + Crumbl Base Protein Cookie"
BB=$(mkroot browned-butter-cookies-gooey);          echo "  + Browned-Butter Protein Cookies (gooey)"
FROST=$(mkroot protein-cream-cheese-frosting);      echo "  + Protein Cream-Cheese Frosting"
RV=$(mkroot red-velvet-cookies);                    echo "  + Red Velvet Protein Cookies"
SUGAR=$(mkroot sugar-cookies);                      echo "  + High-Protein Anti-Pancake Sugar Cookies"
NANAIMO=$(mkroot nanaimo-bars);                     echo "  + High-Protein Nanaimo Bars"
ICS=$(mkroot ice-cream-sandwich);                   echo "  + Protein Ice Cream Sandwich"
FROSTED20=$(mkroot protein-frosted-cookies-20g);    echo "  + 20g Protein Frosted Cookies"
GIANT=$(mkroot giant-single-serve-protein-cookie);  echo "  + Giant Single-Serve Protein Cookie"

echo "deriving variants..."
BANANA=$(build_variant "$DIR/banana-cheesecake.variant.json" "$VP");           echo "  + Banana Butterscotch Cinnamon Cheesecake"
COOLWHIP=$(build_variant "$DIR/cool-whip-frosting.variant.json" "$FROST");     echo "  + Cool-Whip Protein Frosting"
# The Crumbl base is frosted with the Cool-Whip frosting (a sub_recipe pin). The
# source file's pin is a stale live id; re-pin it to the freshly-built Cool-Whip head, THEN
# derive the flavor variants off the re-pinned base so they inherit a live (resolvable) pin.
CRUMBL=$(echo '{}' | jq -c --arg id "$COOLWHIP" '{op:"replace",kind:"slot",target:"sl-frosting",payload:{componentKey:"sl-frosting",name:"vanilla protein frosting",resolution:{kind:"sub_recipe",subRecipeVersionId:$id}}}' | "$BATCH" override "$CRUMBL" -m "reseed: pin cool-whip frosting" | jq -r '.version.id')
echo "  ~ Crumbl base frosting re-pinned -> Cool-Whip"
BIRTHDAY=$(build_variant "$DIR/birthday-cake.variant.json" "$CRUMBL");         echo "  + Birthday Cake Protein Cookies (off Crumbl base)"
LEMON=$(build_variant "$DIR/lemon.variant.json" "$CRUMBL");                    echo "  + Lemon Protein Cookies (off Crumbl base)"
LUCKY=$(build_variant "$DIR/lucky-charms.variant.json" "$CRUMBL");             echo "  + Lucky Charms Protein Cookies (off Crumbl base)"
CHEWY=$(build_variant "$DIR/browned-butter-cookies-chewy.variant.json" "$BB"); echo "  + Browned-Butter Protein Cookies (Soft-Chewy)"
ABL50=$(build_variant "$DIR/browned-butter-cookies-50g.variant.json" "$BB");   echo "  + Browned-Butter Protein Cookies (50g protein)"
ABL60=$(build_variant "$DIR/browned-butter-cookies-60g.variant.json" "$BB");   echo "  + Browned-Butter Protein Cookies (60g protein)"

# --- M3 composition: replace Red Velvet's inline frosting with the frosting sub-recipe pin. ---
echo "composing Red Velvet frosting..."
while read -r entry; do
  entry=$(echo "$entry" | jq -c --arg fid "$FROST" 'if (.payload.resolution.subRecipeRef != null) then .payload.resolution = {kind:"sub_recipe", subRecipeVersionId:$fid} else . end')
  RV=$(echo "$entry" | "$BATCH" override "$RV" -m "reseed: compose frosting" | jq -r '.version.id')
done < <(jq -c '.overrides[]' "$DIR/red-velvet.compose-frosting.json")
echo "  + Red Velvet composed"

# --- Turtle cheesecake: 3 sub-recipes + derive-off-base-cheesecake + compose (self-contained). ---
echo "building Turtle cheesecake..."
bash "$DIR/build-turtle.sh" >/dev/null
TURTLE=$(byname "Turtle Protein Cheesecake")
echo "  + Turtle Protein Cheesecake (+ 3 sub-recipes)"

# --- Tasting feedback: replay the real verdicts (append-only; never writes a version). ---
echo "recording tasting feedback..."
fb() { "$BATCH" feedback add "$@" >/dev/null; }
fb "$BB" --made --rating excellent
fb "$SUGAR" --made --rating good -m "Good taste. Texture came out soft, not very dense as the recipe intends — acceptable, not much to be done about it."
fb "$NANAIMO" --made --rating excellent
fb "$ICS" --made --rating okay -m "Decent. Filling really wants a Ninja Creami churn for texture."
fb "$BANANA" --made --rating excellent
fb "$BIRTHDAY" --made --rating excellent
fb "$LEMON" --made --rating excellent -m "cookie itself is great"
fb "$LEMON" --made --component b5 --rating bad -m "glaze too weak/thin, needs work"
fb "$LUCKY" --made --rating good
fb "$CRUMBL" --to-make -m "First bake of the base — confirm the cornstarch keeps it soft at 2 scoops protein, and that 163 kcal / 14.3 g protein eats like a real crumbl base. If texture holds, bump dough protein 2 -> 2.5 scoops to crack <10 kcal/g."
fb "$RV" --to-make -m "haven't made it yet"
fb "$FROSTED20" --to-make -m "Test the <10 kcal/g-protein claim IRL — 3 scoops whey in 5 cookies is aggressive protein-loading; watch for dry/rubbery 'pancake' texture and whether the 1-cup-yogurt frosting reads as frosting or just wet."
fb "$GIANT" --to-make -m "found on IG, untried - lean yogurt-based cookie"
fb "$ABL50" --to-make -m "protein ablation — not baked yet"
fb "$ABL60" --to-make -m "protein ablation — not baked yet"
fb "$TURTLE" --made --rating excellent -m "First bake, rated excellent on first impression (full taste tomorrow). ~217 cal / 19 g protein per slice (11.5 cal/g)."
echo "  + feedback recorded"

echo "done — $("$BATCH" list | jq length) recipes."
