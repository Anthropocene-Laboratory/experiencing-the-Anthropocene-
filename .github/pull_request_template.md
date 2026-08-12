## Purpose

Describe the research or maintenance question and why this change is needed.

## Analytical role

- [ ] Anthropocene component
- [ ] Layer A — experienceable feature
- [ ] Layer B — exposure filter
- [ ] Layer C — implication
- [ ] Layer D — response capacity
- [ ] Repository infrastructure/documentation only

Explain any cross-layer relationship without combining roles in one variable.

## Sources and licences

List new or changed datasets, versions, DOI/URLs, retrieval dates, checksums, and licence
implications. Write “none” if no source changed.

## Validation performed

```text
Rscript validation/check_repository.R
<smallest relevant workflow command>
```

Report environment, numerical QA/tolerance, and any validation that could not be run.

## Outputs changed

List every generated map, table, or intermediate whose content changed, with the numerical
reason. Do not rely only on a visual diff.

## Checklist

- [ ] I preserved the Layer A/B/C/D distinctions and documented any methodological decision.
- [ ] I updated `data_sources.md` for every source/provenance/licence change.
- [ ] I introduced no credential, confidential file, restricted data, or personal path.
- [ ] I reviewed the staged files for accidental raw or large data.
- [ ] Fast repository checks pass.
- [ ] Documentation and citation metadata are consistent with the change.
- [ ] Existing unrelated worktree changes were preserved.
