# Batch recipe store (version-controlled)

- `db.json` — the live store and **source of truth** (recipes, versions, ingredients, feedback). Every
  CLI change is a commit here. This file, in git and pushed to the private remote, **is the backup** —
  restore by checking out an earlier commit, not by re-running a script.
- `sources/` — a declarative snapshot of the store, **regenerated from it** with `batch dump --out sources`
  (derived, never hand-maintained, so it can't drift). Optional human-readable provenance + the input
  format for `batch import`:
  - `ingredients.json` — the full library.
  - `<recipe>.json` — root recipes as `batch create` payloads.
  - `*.variant.json` — variants as `derive` + an auto-diffed override manifest (base referenced by name).
  - `feedback.json` — the tasting log (pinned by recipe name).
  - `manifest.json` — dependency-ordered build list (a base before its variants, a sub-recipe before any composer).

Sub-recipe pins are stored by NAME (`subRecipeRef`) so they re-resolve against a freshly rebuilt store.

## Refresh the snapshot (after CLI edits)
```
batch dump --out sources
```

## Rebuild a store from sources
`batch import <dir>` replays a dump (ingredients → recipes in dependency order → feedback). Into an empty
store it's a clean rebuild:
```
BATCH_DB=/tmp/fresh/db.json batch import sources
```
`dump` + `import` are a verified round-trip (the rebuilt store reproduces every macro/feedback signature to
the cent) and the manual core of the planned AI-import pipeline. They replace the old hand-maintained
`reseed.sh`, which had drifted out of sync with the store.
