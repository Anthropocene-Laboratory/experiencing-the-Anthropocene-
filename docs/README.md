# Documentation

This folder separates task-oriented guidance from the repository landing page.

| Guide | Use it when… |
|---|---|
| [Getting started](getting-started.md) | installing R/Python, locating data, or running Connectivity and HILDA+ for the first time |
| [Workflow map](workflows.md) | deciding which script to run and which earlier output it requires |
| [Troubleshooting](troubleshooting.md) | diagnosing paths, packages, credentials, downloads, platform issues, or changed results |
| [Reproducibility](reproducibility.md) | assessing the evidence needed to reproduce, validate, archive, or release the work |

Repository-wide references remain at the root:

- [`../README.md`](../README.md) — project landing page and short quickstart;
- [`../data_sources.md`](../data_sources.md) — source provenance, access, checksums, and licences;
- [`../AGENTS.md`](../AGENTS.md) — analytical architecture and classification rules;
- [`../CONTRIBUTING.md`](../CONTRIBUTING.md) — contribution and review workflow;
- [`../LICENSING.md`](../LICENSING.md) — distinct terms for code, inputs, and outputs.

## Why the documentation is split

The README must orient a newcomer quickly. Detailed procedures change at a different
rate and are easier to maintain, review, and link when each has one purpose. This
structure follows the research-compendium guidance in
[The Turing Way](https://book.the-turing-way.org/reproducible-research/compendia/),
the [FAIR4RS principles](https://doi.org/10.15497/RDA00068), and GitHub's guidance on
[repository READMEs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes)
and [contributor documentation](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors).
