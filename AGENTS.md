# Experiencing the Anthropocene - Agent Guide

This workspace supports the project "Experiencing the Anthropocene."
The project maps how human-driven Earth-system transformations are encountered
in daily life through human-facing interfaces, how those exposures are filtered
by social position and time use, and how they relate to health, perception,
polarization, wellbeing, and response capacity.

Use this guide when reading, editing, classifying, or extending project files.
The central rule is: do not collapse the layers. Keep upstream drivers,
experienceable features, exposure filters, implications, and response capacities
analytically separate.

## Source Documents

Primary sources used for this guide:

- `Anthropocene_Project_Roadmap.docx`
- `Project_Tasks.xlsx`
- `Anthropocene_Experience_Taxonomy_v2.canvas`

The roadmap is the narrative source of truth. The task workbook is the execution
tracker. The canvas is the conceptual architecture.

None of the three is distributed with this repository: they are internal working
documents held by the project team. This guide restates everything from them that
is needed to read the code. Ask the maintainers if you need the originals.

## Project Logic

All work sits inside a five-step causal stack:

1. Anthropocene components
   Upstream Earth-human system changes: land-use change, climate forcing,
   biogeochemical flows, infrastructure build-out. These are drivers, not
   experiences.

2. Experienceable features
   Human-facing interfaces through which components become visible, embodied,
   time-structuring, socially relational, or symbolically meaningful. This is
   Layer A and the core data layer.

3. Exposure filters
   Operators that determine who encounters which features, how often, and in
   what form. This is Layer B.

4. Implications
   Downstream outcomes of exposure: health, psychological wellbeing, cognition,
   perception, and social dynamics. This is Layer C.

5. Response capacities
   Capacities that shape how societies navigate change: institutional,
   collective, psychological-cultural, and material-technical. This is Layer D.

Methodological guardrail: every row in the feature library must declare exactly
one analytical role. Without this, the catalogue becomes a list of interesting
datasets rather than a causal architecture.

## Core Distinction

Anthropocene components are not experienceable features.

Example causal line:

- Land-use change = Anthropocene component
- Loss of nearby green space = experienceable feature
- Reduced time outdoors = exposure or behavioral interface
- Subjective wellbeing or polarization = implication
- Community capacity or green parties = response capacity

When classifying variables, ask what role the variable plays in the causal
stack before assigning a sphere, mode, or dataset status.

## Layers

### Layer A: Experienceable Features

Layer A is organized by Peter's spheres. These are the primary ontology for
experienceable features.

A1. Ecological / biospheric

- The biosphere as encountered.
- Examples: altered ecosystems, biodiversity intactness, human footprint,
  land-use change, nearby green space, crop landscapes, water quality,
  pollution, climate hazards, coastal change.

A2. Technosphere / built mediation

- The engineered world as encountered.
- Examples: infrastructure density, transport routes, phone and network
  coverage, data traffic, satellites, AI exposure, digital schooling, clean
  water and sewage infrastructure, visible built environment.

A3. Social organization / everyday life

- How social life is structured.
- Examples: population density, household structure, work form, labor
  structure, food-production involvement, processed food share, food miles,
  time with others, commuting, mobility, living space.

A4. Institutional-symbolic

- The interpretive and governance environment as encountered.
- Examples: governance quality, OECD indicators, World Values Survey domains,
  trust, institutional legitimacy, technosolutionism, optimism about future
  generations, Anthropocene belief systems, sense of place, media, narratives,
  language of change.

Some A4 variables can also matter in Layer D. If so, declare the analytical role
for the row being edited rather than mixing roles in one row.

### Layer B: Exposure Filters

Layer B is not a category of experience. It determines which Layer A features
reach whom, how often, and in what form.

B1. Place and scale

- Urban/rural position, region, country, neighborhood, national income level,
  density, isolation.

B2. Wealth and inequality

- Income, wealth, local inequality, class position, consumption capacity.

B3. Life course and demographics

- Age, generation, life stage, gender, education, household structure,
  occupation, sector.

B4. Time use and Global Human Day

- Time-use structure, daily rhythms, mobility routines, minutes per day by
  activity category.
- Treat Global Human Day as the master exposure operator across spheres.

### Layer C: Implications

Layer C contains outcomes produced by exposure, not the interfaces themselves.

C1. Health and body

- Cancer, obesity, longevity, chronic disease, physiological stress.

C2. Psychological wellbeing

- Subjective wellbeing, eco-anxiety, meaning, hope, depression, loneliness.

C3. Cognition and perception

- Attention, perceived change, future outlook, cognitive capacity, risk
  perception.

C4. Social dynamics

- Polarization, empathy, trust, coalition or fragmentation, collective efficacy.

Do not classify health, wellbeing, polarization, empathy, trust, or cognition as
Layer A features unless the file explicitly concerns how those ideas are
encountered as institutional-symbolic content.

### Layer D: Response Capacities

Layer D contains what enables societies to navigate change. These capacities
can be both context and outcome.

D1. Institutional

- Governance quality, OECD governance indicators, policy readiness, rule of
  law, institutional trust.

D2. Collective

- Coalitions, community capacity, green parties, pro-social businesses, civic
  participation, social movements.

D3. Psychological and cultural

- Hope, agency, resilience, imaginaries of transformation, narrative
  repertoires, cultural adaptability.

D4. Material and technical

- Adaptation resources, green infrastructure, knowledge systems,
  transformative technology, financial instruments.

## Modes of Experience

Denis's modes are a cross-cutting overlay, not a rival top-level ontology.
Every Layer A variable should have a primary sphere tag and at least one mode
tag.

Modes:

- Spatially visible: what is seen in the landscape.
- Materially embodied: what enters bodies, households, or consumption.
- Temporally structuring: what changes how time is spent.
- Socially relational: what changes interaction, dependence, or coordination.
- Symbolically interpreted: what is known through narrative, media, values, or
  belief.

Also score directness:

- Direct
- Mediated
- Abstract

## Excel Library Guardrail

The feature library should include these mandatory classification fields:

1. Analytical role: component, experienceable feature, exposure conditioner,
   implication, response capacity.
2. Primary sphere tag: ecological, technosphere, social organization,
   institutional-symbolic.
3. Mode of experience: space, matter, time, relation, meaning; at least one.
4. Directness of experience: direct, mediated, abstract.
5. Likely mechanism: visual, bodily, temporal, social, symbolic.
6. Unit of analysis: raster, admin unit, survey, network, text.
7. Spatial joinability: yes, partial, no.
8. Temporal update frequency: realtime, annual, periodic, one-shot.
9. Comparability across countries: high, medium, low.
10. Major bias or caveat: free text.
11. Valence: degrading, compensatory, restorative, regenerative.

## Project Phases

Phase 0: Conceptual framing

- Status: in progress.
- Goal: agree on the layered architecture and methodological guardrail.
- Deliverables: V2 canvas, framing one-liner, variable-reclassification note.
- Done when the team can place any candidate variable into one pipeline step
  without debate.

Phase 1: Inventory and feature library

- Status: in progress.
- Goal: build one auditable catalogue of datasets and features.
- Deliverable: unified per-sphere feature catalogue for A1-A4.
- Current emphasis: complete A3 and A4 catalogues, populate classification and
  experience-mode blocks, reconcile the 11 mandatory fields with the 37-field
  catalogue schema, and reroute Denis's original variables into A, C, or D.

Phase 2: Feature ranking and priority

- Status: to do.
- Goal: move from a flat feature list to a defensible shortlist.
- Ranking spine: scale, speed, magnitude, connectivity.
- Deliverables: scoring rubric, per-feature scores, composite ranking, Core /
  Shortlist / Hold placement, one-line justifications.

Phase 3: Exposure filters operationalization

- Status: to do.
- Goal: turn Layer B into operators that transform Layer A features into
  population exposure profiles.
- Deliverables: B1-B4 operational schema, Global Human Day integration, worked
  example such as green-space access.

Phase 4: Modes of experience tagging

- Status: to do.
- Goal: tag every Layer A variable by experiential mode and directness.
- Deliverables: mode tags, directness scores, sphere x mode coverage matrix.

Phase 5: Implications and response coupling

- Status: to do.
- Goal: map Layer A features to Layer C implications and Layer D capacities.
- Deliverables: A -> C matrix, A -> D matrix, and list of dual A4/D1 variables.

Phase 6: Data assembly and spatial join

- Status: to do.
- Goal: move from catalogue to working dataset.
- Deliverables: source files for Core features, target spatial harmonization
  unit, population-weighted overlays, joinability log.
- Dependencies: Phase 2 ranking and Phase 3 exposure schema.

Phase 7: Analysis and synthesis

- Status: to do.
- Goal: produce substantive findings about how the Anthropocene is encountered,
  by whom, and with what implications.
- Deliverables: cross-sphere exposure profiles, exposure typology, key findings
  linking A profiles to C implications and D capacities.

Phase 8: Communication and dissemination

- Status: to do.
- Goal: translate the architecture and findings into outputs.
- Deliverables: paper draft, layered-pipeline figure, exposure-profile diagrams,
  internal AnthLab deck, external partner deck.

## Open Decisions to Preserve

Do not silently resolve these without documenting the decision:

- Population denominator: global population, within-country population, or
  per-capita comparison.
- Spatial unit of harmonization: raster, administrative unit, or hybrid.
- Temporal baseline: single global baseline or per-feature baseline.
- Treatment of mediated and abstract features.
- Depth of A3 and A4 refresh relative to A1 and A2.
- Aggregation rule for the Phase 2 ranking axes.

## Working Rules for Agents

- Preserve the layered architecture in all edits.
- Before adding a dataset, identify its analytical role.
- Before moving a variable, ask whether it is a driver, interface, filter,
  outcome, or capacity.
- Keep spheres and modes separate: sphere is the primary ontology; mode is the
  cross-cutting experiential overlay.
- Treat Global Human Day as an exposure operator, not as a Layer A feature.
- Keep roadmap, task tracker, canvas, and feature-library schema aligned when
  changing project structure.
- When adding decisions, record both the decision and its rationale.
- Prefer concise edits that strengthen classification, traceability, and causal
  logic.
