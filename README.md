# teaching-data

Course datasets and their data cards, versioned by release tag.

This repo is the **distribution layer**: clean, course-ready files plus the
documentation that travels with them. It is what the book, the lecture decks,
the problem sets, and each semester's course repo actually fetch.

The **workshop** stays where it is — `~/Dropbox/data/`, roughly 3.3 GB of raw
sources, replication archives, extraction and cleaning scripts, and exploratory
analyses. That tree is not a git repo and is not going to become one. Only the
finished outputs cross over, and only the ones named in `manifest.yml`.

## Layout

```
manifest.yml          one entry per dataset: files + sha256, delivery
                      mechanism, Canvas label, source/license, archive pointer
cards/*.qmd           the 11 data cards -- canonical home
data/<name>/...       the datasets themselves
tools/fetch_data.sh   <tag> <dest>: materialize one pinned version
tools/make_release.sh <tag>: build the release zips and checksums
tools/promote.sh      <name>: refresh a dataset from the Dropbox archive
LICENSING.md          the card-driven public/restricted pass
```

### Two delivery mechanisms

Most datasets are small and are tracked as plain git — about 4 MB in total, no
LFS. Four are not: `soc` (152 MB), `ercot` (68 MB), `lending_club` (48 MB), and
`austin_houses` (19 MB). Those ship as **GitHub Release assets**, one zip per
dataset per tag, and their paths are gitignored. `manifest.yml` records which
is which under `delivery:` (`tracked` or `release-zip`), and `fetch_data.sh`
handles both without the consumer needing to know or care.

The manifest also records **canonical delivered filenames**. Chapter code reads
`data/soc/soc_clean.csv`, but 152 MB of CSV is shipped gzipped, so the release
zip carries `soc_clean.csv.gz` (recorded as `packaged_as:`) and `fetch_data.sh`
gunzips it to the name the sources expect. What lands in `<dest>` always matches
what the code reads.

### Cards

The 11 data cards live in `cards/`. They are student- and book-facing documents
that must version with the data they describe, which is why they moved out of
the book's gitignored `data/` tree. They use `@citations` resolved by the book's
`references.bib` and render only inside the book — that's fine and intended, and
it means the cards should not be edited to "fix" their citations.

## Pinning

**Release tag = data version** (`v2026.08`, `v2027.01`, …). Every consumer — the
book, the master decks, each semester's course repo — carries a one-line
`data_pin` naming a tag. Numbers in the notes cannot drift unless someone moves
the pin, deliberately.

Fetching a pin into an empty directory:

```sh
tools/fetch_data.sh v2026.08 ~/course/2026-fall
```

That pulls the tracked files and cards from the tag's source tarball, downloads
the release zips for that tag, verifies every file against the sha256 recorded
in **that tag's** `manifest.yml`, unpacks to the canonical filenames, and drops
the manifest into `<dest>/manifest.yml` — the Canvas dataset-label scan reads
`label:` from the offering's local copy at scan time.

Public release assets come down over plain `curl`. Restricted ones (see
`LICENSING.md`) come down via `gh release download` from `$RESTRICTED_REPO`,
which is an overridable variable in `tools/lib/common.sh` — where restricted
assets are hosted is still an open question, and the fetch path is written so
either answer works.

Pulling a dataset back later breaks *old tags'* fetches for archived offerings.
That is accepted and noted in the card convention.

## Adding or updating a dataset

1. Do the work in the archive, as always: `~/Dropbox/data/<name>/`, with the raw
   sources and the cleaning script beside each other.
2. Declare the finished outputs in `manifest.yml` under that dataset's `files:`
   list. For a brand-new dataset, add the whole entry — `label:` verbatim from
   the book's `data.qmd` heading, `card:`, `delivery:`, `restricted:`,
   `archive_dir:`, `source:`, `license:`. sha256 and bytes can start as
   placeholders.
3. `tools/promote.sh <name>` — copies the declared files in and recomputes their
   hashes and sizes in the manifest. **Only declared files ever move.**
   Everything else in the archive directory is workshop material and stays put;
   that is the whole point of keeping the declared list in the manifest rather
   than in a sidecar inside an unversioned Dropbox tree. `DRY_RUN=1` shows what
   would happen.
4. Review `git diff manifest.yml`, commit.
5. Cut a tag when you want a new version — an explicit step, never automatic.
   `tools/make_release.sh <tag>` builds the zips and checksums into
   `release/<tag>/` and *prints* the `gh release create` command with all the
   assets attached. Running it is your call.
6. Move each consumer's `data_pin` to the new tag when you want it to pick the
   version up.

`promote.sh` only ever reads the archive. Propagating anything in the other
direction is a separate, deliberate operation.
