# Licensing pass

Every data card in `cards/` was grepped for provenance, license, source, terms,
copyright, and access language, and each dataset is summarized below from what
its card actually says — not from memory. Where a card is silent, that silence
is recorded as silence.

The default is **restricted**: a dataset ships publicly only when its card
states a redistribution-permitting license, or the underlying material is a
public-agency record or already redistributed publicly by a third party under a
license. Pulling a dataset back after a public release un-distributes nothing,
so the cost of being wrong is asymmetric.

`restricted: true` in `manifest.yml` means the dataset's release asset is not
served anonymously; `fetch_data.sh` pulls it with `gh release download` from
`$RESTRICTED_REPO` instead of plain `curl`. The public card says "obtain from
source."

**Final adjudication is Jared's.** This file is the evidence, not the ruling.

## Summary

| Dataset | Card | Card's license language | Recommendation |
|---|---|---|---|
| `austin_houses` | `data-housing-kaggle.qmd` | "distributed via Kaggle without a formal license; access requires a Kaggle account" | **restricted** |
| `mincer` | `data-earnings-cps.qmd` | "No license restrictions apply to CPS public-use files; the data are freely available from the U.S. Census Bureau" | public |
| `returns` | `data-returns-2025.qmd` | "Yahoo Finance terms of use restrict redistribution of raw price data; this assembled dataset is intended for educational use" | **restricted** |
| `portfolios` | `data-portfolios-2025.qmd` | same Yahoo language as `returns` | **restricted** |
| `ercot` | `data-ercot-shaffer.qmd` | silent on license; ERCOT operating records + NOAA LCD, "curated by Blake Shaffer and archived at the replication repository" | public |
| `lending_club` | `data-lendingclub-kaggle.qmd` | "consult that page for current license terms" — no license asserted; Kaggle-gated | **restricted** |
| `sap_roe` | `data-sap-nucleus.qmd` | silent on license; transcribed from Table 1 of a published research note | public |
| `kroger_cheese` | `data-kroger-cheese.qmd` | "No formal license is stated; the data are made available for educational use through the book's online companion" | **restricted** |
| `bloom_wfh` | `data-wfh-bloom.qmd` | "freely available under a Creative Commons CC BY 4.0 licence" | public |
| `soc` | `data-consumer-soc.qmd` | silent on license; UMich Survey Research Center microdata | **restricted** |
| `hamermesh_evals` | `data-evals-hamermesh.qmd` | silent on license; "distributed in the R package AER as `TeachingRatings`" | public |

Six restricted, five public.

## Per dataset

### austin_houses — restricted (pre-decided in the plan)

Zillow listings scraped by Eric Pierce, published on Kaggle in 2021. The card is
explicit: no formal license, and access requires a Kaggle account. Redistributing
a 9 MB copy would route around the gate the source chose.

### mincer — public

2023 CPS ASEC public-use microdata retrieved through the `cpsR` package. The card
affirmatively states there are no license restrictions on CPS public-use files.
This is the cleanest public case in the set.

### returns — restricted (pre-decided)

Adjusted daily closes retrieved from Yahoo Finance via `tidyquant`. The card
itself states Yahoo's terms restrict redistribution of raw price data and scopes
the assembled dataset to educational use. Note that `returns_prices.csv` carries
adjusted closing *price levels*, which is the form the terms speak to most
directly; `returns.csv` holds derived weekly returns, which is a weaker case for
restriction but travels with the same card and the same source.

### portfolios — restricted (pre-decided)

Same retrieval path, same Yahoo terms language, same reasoning. `portfolios.csv`
shares its `SPY` series with `returns`, so the two must be classified together
regardless of how the derived-versus-raw question resolves.

### ercot — public

Hourly zonal load from ERCOT plus NOAA Local Climatological Data temperatures,
matched and curated by Blake Shaffer. The card states no license. Both upstream
sources are public-agency records, and the curated panel is already published in
a public replication repository (`github.com/blakeshaffer/ercotproject`) tied to
a journal article, so redistribution here adds no exposure the source has not
already accepted. Public, but the silence is worth a glance during adjudication.

### lending_club — restricted (**finding beyond the plan's pre-decided five**)

The card explicitly declines to state terms: "Data are available at the Kaggle
dataset page linked above; consult that page for current license terms." The
underlying loan-performance files were public LendingClub releases, but the
compiled Kaggle dataset (Nathan George / *wordsforthewise*) is account-gated,
exactly the situation the plan named for `austin_houses`. Same gate, same
deferral, same treatment.

### sap_roe — public

81 rows transcribed from Table 1 of Nucleus Research note G12 (2006): company,
industry, ROE, industry-average ROE, plus one derived column added for this
book. Factual financial figures from a note that circulates publicly today via
Oracle's own site. The card is silent on license, but the volume and the nature
of the content put this well inside ordinary scholarly reuse.

### kroger_cheese — restricted (pre-decided)

Compiled by James Scott for *Data Science in R: A Gentle Introduction*. The card
states no formal license, only that the data are made available for educational
use via the book's companion. Third-party teaching material with no license
grant; the courteous default is to point at the source.

### soc — restricted (pre-decided)

A processed extract of University of Michigan Surveys of Consumers microdata.
The card documents the survey design and the cleaning steps in detail but states
no license and links only to `data.sca.isr.umich.edu`. Redistribution rights for
ISR microdata are not established by anything in the card, and this is the
largest file in the set (152 MB), so it is also the most conspicuous.

### bloom_wfh — public

Bloom, Han & Liang (2024). The card names the license outright: the Harvard
Dataverse replication archive (doi:10.7910/DVN/6X4ZZL) is CC BY 4.0, and the
article was open access in *Nature*. Attribution is already carried by the card.

### hamermesh_evals — public

Hamermesh & Parker (2005) course evaluations. The card is silent on license, but
records that this exact teaching extract is distributed on CRAN in the `AER`
package as `TeachingRatings` — a third party is already redistributing it
publicly under an open license. The one extra column, `generation`, is a recode
of `age` created for this book. Note that this is the one dataset with no
Dropbox archive directory at all; the repo copy is the only copy.

## Open item, not resolved here

A public GitHub repository cannot host private release assets. Where the
restricted zips actually live — a private mirror repo, a university-hosted
location, or Canvas-only distribution — is left open by the refactor plan and is
not decided here. `fetch_data.sh` is built so that either answer works: it reads
the per-dataset `restricted:` flag from the manifest and takes the host from an
overridable `RESTRICTED_REPO` variable.

## Rulings (Jared, 2026-08-02)

- **austin_houses, lending_club, kroger_cheese → public.** Accepted risk:
  all three circulate widely in public-facing repos already; the pull-back
  path (re-restrict in a future tag, "obtain from source" card) remains if a
  rights-holder objects. `restricted: false` in the manifest as of this
  commit.
- **returns, portfolios → stay restricted pending an alternative delivery.**
  Direction: the public-facing object may be an R script that reproduces the
  datasets rather than the data files themselves; alternative sources under
  research. Constraint: course numbers are pinned to these exact CSVs, so a
  re-fetch that is only approximately equal changes displayed numbers.
- **soc → stays restricted; needs more attention.** Options under
  consideration: migrate the examples to a federal survey with permissive
  terms, or document reconstruction of the course examples from the public
  SCA data export (a simpler export-and-process path than the original
  full-microdata build). Students currently touch soc only through rendered
  examples, not directly.
