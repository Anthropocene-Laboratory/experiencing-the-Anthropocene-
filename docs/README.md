# Documentation

This folder separates task-oriented guidance from the repository landing page.

| Guide | Use it when… |
|---|---|
| [Getting started](getting-started.md) | installing R/Python, locating data, or running Connectivity and HILDA+ for the first time |
| [Workflow map](workflows.md) | deciding which script to run and which earlier output it requires |
| [Troubleshooting](troubleshooting.md) | diagnosing paths, packages, credentials, downloads, platform issues, or changed results |
| [Reproducibility](reproducibility.md) | assessing the evidence needed to reproduce, validate, archive, or release the work |
| [Project architecture](project-architecture.md) | understanding the causal stack, analytical layers, modes, phases, and open decisions |
| [Repository conventions](repository-conventions.md) | deciding where code, inputs, intermediates, figures, tables, and notes belong |
| [Data sources](data-sources.md) | finding provenance, access routes, target paths, checksums, and input licences |
| [Licensing](licensing.md) | determining how code, source data, figures, and tables may be reused |

Repository-wide references remain at the root:

- [`../README.md`](../README.md) — project landing page and short quickstart;
- [`../.github/CONTRIBUTING.md`](../.github/CONTRIBUTING.md) — contribution and review workflow;
- [`../CITATION.cff`](../CITATION.cff) — machine-readable citation metadata;
- [`../LICENSE`](../LICENSE) — software licence.

Repository-level executable entry points live in `scripts/`; feature-specific
processing code remains beside its feature under `Feature explorations/`.

## Why the documentation is split

The README must orient a newcomer quickly. Detailed procedures change at a different
rate and are easier to maintain, review, and link when each has one purpose. This
structure follows the research-compendium guidance in
[The Turing Way](https://book.the-turing-way.org/reproducible-research/compendia/),
the [FAIR4RS principles](https://doi.org/10.15497/RDA00068), and GitHub's guidance on
[repository READMEs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes)
and [contributor documentation](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors).
