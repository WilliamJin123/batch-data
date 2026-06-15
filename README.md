# Batch recipe store (version-controlled)

- `db.json` — the live store and source of truth (recipes, versions, ingredients). Every CLI change is a commit here.
- `sources/` — declarative re-seed inputs extracted from the store:
  - `ingredients.json` — the full library.
  - `<recipe>.json` — root recipes as `batch create --file` payloads.
  - `*.variant.json` — derived variants (base ref + override manifest); replayed by reseed.sh.
  - `reseed.sh` — rebuild the whole store INTO AN EMPTY store: `BATCH_DB=/tmp/fresh/db.json bash sources/reseed.sh`

Note: roots serialize to a single create-file; variants need base + override manifest (no single-file form yet).
Unifying both into one `batch import <dir>` is the manual core of the planned AI-import pipeline.
