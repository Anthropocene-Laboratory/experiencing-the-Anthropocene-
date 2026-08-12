# Contributing

Thank you for helping improve Experiencing the Anthropocene. Contributions can be code,
data-source corrections, documentation, validation, or scientific-method discussions.

This is exploratory research software. A change is ready for review only when its
scientific role, provenance, and effect on outputs are as clear as its code.

## Before starting

1. Read [`../README.md`](../README.md),
   [`../docs/project-architecture.md`](../docs/project-architecture.md), and the relevant
   feature note.
2. Search existing issues before opening a new one.
3. For a substantial change, open an issue describing the question, affected workflow,
   evidence, and proposed validation before writing code.
4. Do not use issues or pull requests to share credentials, confidential files, licensed
   source data, or personal filesystem paths.

Use the repository issue forms:

- **Usage question** for help installing, locating data, or following a documented workflow;
- **Bug report** for a script that fails or behaves differently from its documented contract;
- **Data/provenance problem** for access, version, checksum, coverage, licence, or source concerns;
- **Scientific-method question** for classification, assumptions, thresholds, or interpretation.

## Branch and review workflow

- Create a short-lived branch from current `main`.
- Use a descriptive name such as `fix/hilda-manual-archive` or
  `docs/first-run-workflow`.
- Keep commits focused and use messages that explain the reason for the change.
- Open a pull request; do not push unreviewed work directly to `main`.
- Complete the pull-request checklist and identify any generated maps or tables that
  changed.
- At least one project maintainer should review changes affecting scientific outputs,
  source provenance, licences, the analytical architecture, or environment locks.

## Analytical guardrails

Every variable must have exactly one role in the causal stack:

- Anthropocene component;
- Layer-A experienceable feature;
- Layer-B exposure filter;
- Layer-C implication;
- Layer-D response capacity.

Do not mix roles in one field or move population, wealth, demographics, time use, health,
wellbeing, cognition, or response capacity into Layer A for analytical convenience. Keep
Peter's spheres separate from Denis's modes of experience. Full definitions and open
project decisions are in
[`../docs/project-architecture.md`](../docs/project-architecture.md).

## Code and path contract

- R feature scripts must resolve the repository with `here::here()`; Python scripts must
  resolve from `Path(__file__)`.
- Never commit a personal absolute path or add `setwd()` to a personal directory.
- Inputs go in `data_raw/`; intermediates go at the `data_processed/` root; final PNGs and
  CSVs go in `data_processed/maps/` and `data_processed/tables/`.
- Raw and large raster data must not be committed. Respect `.gitignore` and verify the
  staged file list before committing.
- A script must fail with a useful message when a required input is absent; it must not
  silently substitute another file or download a landing-page HTML response.
- Preserve deterministic seeds, units, CRS, temporal windows, and declared thresholds.
- Do not rewrite `renv.lock` unless the dependency update is intentional, reviewed, and
  described.

## Data-source changes

Any new or changed source requires a matching update to
[`../docs/data-sources.md`](../docs/data-sources.md).
Record the provider, version, DOI or exact URL, retrieval route, target path, coverage,
resolution, CRS, units, size, checksum where possible, licence, processing script, outputs,
and major biases.

Separate evidence levels:

- observed metadata or measured values;
- calculations made by repository code;
- methodological assumptions or sizing rules;
- deductions that follow from cited evidence.

Do not claim “downloadable”, “complete”, “reproduced”, or “validated” without checking the
exact current source or output.

## Validation before a pull request

Run the fast repository checks:

```powershell
Rscript validation/check_repository.R
```

Then run the smallest relevant workflow. Record:

- exact command;
- input identity and checksum if available;
- operating system, R version, and geospatial library versions;
- output files created or changed;
- numerical QA, expected tolerance, and known deviations;
- whether any licence or attribution obligation changed.

Do not regenerate unrelated maps or tables. If a binary figure changes, include the
numerical evidence that explains why; visual similarity or difference alone is not enough.

## Pull-request checklist

- [ ] The scientific question and analytical role are stated.
- [ ] No Layer-A/B/C/D distinction was collapsed.
- [ ] Source provenance and licence are documented.
- [ ] Paths are portable and no secret or personal path is present.
- [ ] Fast repository checks pass.
- [ ] The relevant workflow was run, or the reason it could not be run is explicit.
- [ ] Changed outputs and numerical QA are listed.
- [ ] Documentation and citation metadata are updated where needed.
- [ ] Existing unrelated worktree changes were not overwritten.

## Authorship, citation, and credit

Contributions do not automatically determine publication authorship. Discuss substantial
scientific contributions with the project leads early, and use transparent contribution
statements when a manuscript or release is prepared. Add contributors to citation metadata
only with their confirmed name, affiliation, and ORCID.

## Conduct

Participation is governed by [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md). Scientific
disagreement is welcome; personal attacks, harassment, and disclosure of private material
are not.
