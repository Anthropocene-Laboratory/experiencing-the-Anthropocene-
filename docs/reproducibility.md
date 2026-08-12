# Reproducibility and reuse

[Documentation index](README.md) · [Workflow map](workflows.md) · [Data sources](../data_sources.md)

This repository is an evolving research compendium, not yet a fully executable one. It
separates code, source data, intermediate products, and selected outputs; records software
environments; and documents how inputs are obtained. Several manual sources and
platform-specific acquisition steps still prevent a clean clone from rebuilding every
committed result without intervention.

## Reproducibility levels

Use precise claims:

| Claim | Evidence required |
|---|---|
| repository structurally valid | `Rscript validation/check_repository.R` passes |
| script executed | exit code zero and expected output exists |
| output reproduced | same input identity, environment, parameters, and numerical QA within a stated tolerance |
| figure reproduced | underlying numerical output reproduced; rendering differences separately explained |
| analysis reproduced | all upstream feature products and predefined diagnostics reproduced |
| result independently replicated | independent data or implementation supports the substantive finding |

Passing a syntax check or recreating a PNG is not enough to claim scientific
reproducibility.

## Current reproducibility assets

- Git version history and a public repository;
- `renv.lock` for R dependencies and `requirements.txt` for Python acquisition tools;
- `.here` plus script-relative Python paths for machine-independent locations;
- `download_data.R` as an acquisition catalogue and dispatcher;
- `data_sources.md` for provenance, versions, routes, sizes, licences, and available
  checksums;
- committed PNG/CSV comparison artifacts;
- feature notes recording known methodological limitations;
- validation scripts and explicit fail criteria in the cross-feature analysis;
- `CITATION.cff` for software citation metadata.

## Known gaps

- Some raw inputs require a login, form, click-through, or manual selection.
- Not every source has a recorded checksum.
- Several acquisition workarounds are Windows-only.
- GDAL, PROJ, and GEOS are provided by the operating system and are not pinned by `renv`.
- There is no tested one-command dependency graph for rebuilding every output.
- Large workflows are not run in continuous integration.
- The repository has no formal release or archival DOI yet.
- The `CITATION.cff` author list is explicitly provisional.
- Final output licensing is dataset-dependent and not represented by one blanket licence.

These are limitations to document and reduce, not reasons to imply that the repository is
more reproducible than current evidence supports.

## Reproduction record

For a result that will be circulated or cited, record:

```text
repository commit:
script and command:
run date:
operating system:
R and Python versions:
GDAL / PROJ / GEOS versions:
input dataset versions:
input checksums or immutable identifiers:
parameters and temporal window:
expected outputs:
numerical QA or tolerance:
known deviations:
licence/attribution checked:
```

Attach this record to a pull request, issue, release note, or publication supplement as
appropriate. Never record secrets or confidential local paths.

## Adding or changing a data source

Before changing code, identify the variable's single analytical role: upstream component,
experienceable feature, exposure filter, implication, or response capacity. Then update
`data_sources.md` with:

- provider, title, version, DOI or exact stable URL;
- access and retrieval date;
- native spatial/temporal coverage, resolution, CRS, units, and format;
- acquisition route and exact local target;
- file size and checksum where available;
- licence and downstream obligations;
- processing script and generated outputs;
- known selection, measurement, and comparability biases.

If a source changes a conceptual or methodological decision, document the decision and
rationale rather than silently replacing the old input.

## Release and archiving checklist

Before the first citable release:

1. confirm contributors, authorship, affiliations, and ORCIDs in `CITATION.cff`;
2. choose and document the version number and release scope;
3. rerun structural checks and the relevant scientific workflows;
4. freeze source identities and record checksums where licences permit;
5. review code, input, and output licences separately;
6. create a GitHub release and archive it in a research repository such as Zenodo;
7. add the resulting persistent identifier back to the citation metadata;
8. preserve metadata even if restricted data cannot be archived.

## Standards informing this repository

- [The Turing Way research-compendium guidance](https://book.the-turing-way.org/reproducible-research/compendia/) recommends a conventional structure, separation of data/methods/outputs, a specified computational environment, and a README landing page.
- [The Turing Way collaborative-documentation guidance](https://book.the-turing-way.org/project-design/pd-overview/pd-overview-repro/) treats communication and collaboration practices as part of reproducibility.
- The [Software Sustainability Institute's documentation guidance](https://www.software.ac.uk/blog/what-are-best-practices-research-software-documentation) recommends matching documentation to its audience: beginner how-to material for onboarding and developer/contribution guidance for collaboration.
- [FAIR4RS](https://doi.org/10.15497/RDA00068) calls for findable metadata, standard access, interoperability, clear licences, provenance, and community standards for reusable research software.
- [GitHub's community-profile guidance](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/about-community-profiles-for-public-repositories) recommends README, licence, contribution guidance, a code of conduct, and issue/PR templates for public collaboration.
