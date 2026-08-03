# Reconstructing the `soc` extract from the public SCA archive

`soc` (Surveys of Consumers microdata, 342,346 interviews, 1978–2026) is the
one course dataset that does not ship publicly. The University of Michigan's
usage agreement (https://data.sca.isr.umich.edu/agreement.php) prohibits
redistributing data from the SCA site without written consent, and there is no
derived-data carve-out. It ships only as a restricted release asset
(`gh release download`, repo collaborators), and students meet it only through
rendered examples in the course notes.

Anyone else can rebuild an equivalent extract themselves — the source archive
is public, free, and does not require registration:

1. **Fetch.** The SDA Cross-Section Archive at
   https://data.sca.isr.umich.edu/sda.php exports CSV / tab-delimited
   extracts of the pooled microdata. Select the variables listed in the data
   card (`cards/data-consumer-soc.qmd` — the Variables table is the complete
   list) and download the full 1978–present pooled file.
2. **Process.** The course file `soc_clean.csv` applies three mechanical
   transformations to the raw export, documented in the card's Provenance
   note: variable names standardized to snake_case; numeric missing-value
   codes replaced with `NA` (except the numeric-probability DK code 998,
   which is retained — filter to values ≤ 100 before computing statistics);
   and a companion `{variable}_label` text column added for every categorical
   variable using the codebook's value labels
   (https://data.sca.isr.umich.edu/ codebook, mirrored in the workshop
   archive).
3. **Verify.** Row count for the course vintage: 342,346 interviews over 578
   survey months (January 1978 – February 2026). A later export will have
   more months; course examples subset by `survey_date`, so results for the
   covered window reproduce.

The original full-microdata build (the workshop archive's `process.R`) did
more work than a rebuild needs — it started from the raw fixed-format
microdata rather than the SDA export. The SDA path above is the simpler
supported route.

If you want the exact course file rather than a reconstruction, ask — the
usage agreement contemplates written consent from the University of Michigan
for redistribution, and access to the restricted asset can be granted for
course-related work.
