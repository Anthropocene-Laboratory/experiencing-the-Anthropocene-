# Workflow `%wild` / `%domesticated` / `%built-up`

Travail exploratoire, pas un résultat arrêté. Les règles ci-dessous sont révisables,
et deux décisions de méthode sont encore ouvertes — elles sont signalées comme telles.

## Objectif

Construire, sans proxy de population, une partition spatiale additive de la surface terrestre :

- `wild` : aucune transformation ou gestion humaine détectable par les sources retenues ;
- `domesticated` : territoire transformé ou géré ;
- `built-up` : classe urbaine HILDA dans la partition principale ;
- `unresolved` : surface que les sources ne permettent pas encore d'attribuer sans hypothèse.

`wild` est une **étiquette relative aux sources**, pas une propriété du terrain. Elle
signifie « ni bâti, ni cultivé, ni pâturé, ni forêt gérée, *selon HILDA et Lesiv* ».
Le pâturage extensif, la gestion par le feu, le dépôt azoté et toute déforestation
antérieure à 1960 y sont invisibles. Sur une carte destinée à un tiers, la légende doit
porter cette restriction, pas seulement le mot `wild`.

Le script opérationnel est [`scripts/5_build_wild_domesticated_built.R`](scripts/5_build_wild_domesticated_built.R).
Il produit les pourcentages et les surfaces en m² pour chaque cellule cible. Les
indicateurs HILDA sont convertis en couches indicatrices binaires **avant** toute
reprojection, puis projetés en moyenne d'aire sur une grille intermédiaire égale à 1 km
(`--analysis-km=1`) et agrégés. Ce n'est donc jamais une carte catégorielle reprojetée
puis recomptée, ce qui est le biais que la reprojection directe vers 10 ou 30 km
introduirait.

## Ce que le produit dit, et ce qu'il ne dit pas encore

Le raster Lesiv a été téléchargé le 26 août 2026 (MD5 vérifié) et 2015 est désormais
calculé avec le découpage forestier. Résultat sur l'Europe à 10 km
(`tables/trajectory_summary_10km.csv`) :

| | 2015 sans Lesiv | 2015 avec Lesiv |
|---|---|---|
| `pct_wild` | 17,39 % | **19,86 %** |
| `pct_domesticated` | 40,72 % | **71,61 %** |
| `pct_built_up` | 3,80 % | 3,80 % |
| `pct_unresolved` | 38,09 % | **4,74 %** |

Lesiv résout 33,36 des 38,09 points de forêt : **2,47 pp vers `wild`, 30,89 pp vers
`domesticated`**. Autrement dit **92,6 % de la forêt européenne que Lesiv sait classer
porte une signature de gestion**. Les 4,74 pp restants sont la forêt que Lesiv ne classe
pas (`0`, NoData, autre code).

Ce résultat est à retenir pour ce qu'il dit du choix de méthode : le bucket `unresolved`
ne cachait pas une ignorance symétrique, il cachait une masse très majoritairement
domestiquée. Le « 41 % domestiqué » lu sans Lesiv était une sous-estimation structurelle,
pas une prudence. Laisser l'incertitude dans `unresolved` reste le bon principe — mais il
faut lire ce que le bucket contient avant d'en tirer une phrase.

**1960 et 2019 restent sans Lesiv**, donc `pct_wild` y vaut toujours seulement les classes
HILDA `55` et `66`, et `pct_unresolved` y reste à 31,8 % et 38,2 %. La trajectoire demandée
n'a donc toujours pas de réponse homogène : voir la décision ouverte n° 1 et la troisième
voie mesurée ci-dessous.

## Structure : emboîtée, pas fratrie

La première version traitait `wild`, `domesticated` et `built_up` comme trois catégories
**sœurs**. C'était une erreur de structure : une ville est du territoire transformé par
excellence, et la placer *à côté* de `domesticated` faisait que ce chiffre sous-estimait la
transformation humaine.

La lecture correcte est emboîtée :

```text
wild  +  anthropisé  +  non résolu  =  100 %
              │
              ├── domestiqué non bâti
              └── bâti
```

Sur 2015 : **19,86 % wild, 75,41 % anthropisé** (dont 3,80 bâti), 4,74 % non résolu. Le
« 71,6 % domestiqué » lu isolément manquait presque 4 points.

Les colonnes plates sont **conservées** — le .docx de méthodes et le living doc les
citent — et `pct_anthropogenic` s'ajoute à côté. Sur les cartes, la composante s'intitule
désormais `Domesticated (non-built)` : l'ancien libellé était la moitié visible de
l'erreur.

L'identité de premier niveau est, comme C0, vraie **par construction**. Elle ne compte pas
comme un contrôle.

## Le gradient : hémérobie

La structure emboîtée dit encore « trois cases ». Ce qu'une personne rencontre, c'est le
caractère d'ensemble d'un lieu — un continuum du sauvage à l'urbain.

Le projet contenait déjà ce gradient sans s'en servir :
[`1_map_biosphere_anthromes.R`](scripts/1_map_biosphere_anthromes.R) construit six niveaux
ordonnés Wildlands → Dense settlements. Il a été écarté pour une raison valable — la
typologie Anthromes incorpore la **population**, ce que cette feature existe pour éviter.

L'**hémérobie** résout la tension : échelle ordinale du degré de transformation humaine,
définie sur l'usage du sol **seul**. Proposée comme indicateur de naturalité pour l'UE,
appliquée à CORINE en Allemagne, Autriche, Finlande, Hongrie, Lituanie.

| Degré | Nom | Classes |
|---|---|---|
| 1 | ahémérobe | HILDA `66` végétation éparse / nulle |
| 2 | oligohémérobe | HILDA `55` ; Lesiv `11` forêt sans signature de gestion |
| 3 | mésohémérobe | Lesiv `20`, `31`, `32` forêt gérée, plantée |
| 4 | β-euhémérobe | HILDA `33` pâturage ; `24` agroforesterie |
| 5 | α-euhémérobe | HILDA `22` cultures annuelles ; `23` cultures pérennes |
| 6 | polyhémérobe | HILDA `11` urbain |

**Cette table est un jugement ancré dans la littérature, pas une mesure.** C'est le point
avec lequel il faut se disputer, et il est écrit en un seul endroit dans le script pour
cette raison.

La forêt en est délibérément absente hors Lesiv : HILDA distingue les forêts
**botaniquement** (type de feuille, phénologie) et ne porte aucune information de gestion.

**Le degré 7 (métahémérobe, sol scellé) n'est pas attribué.** Il séparerait le péri-urbain
du cœur bâti via la fraction WSF3D, déjà sur le disque — mais ce partage exige un **seuil**
sur la fraction bâtie, et aucune valeur justifiée n'existe. En choisir une reviendrait à
poser un nombre inventé au sommet de l'échelle. L'urbain reste au degré 6, et
`run_config.csv` enregistre `hemeroby_scale = ordinal 1-6`.

### Sorties et garde de couverture

`pct_hemeroby_1..6` (les parts, pour que la moyenne reste auditable),
`hemeroby_coverage_pct`, `hemeroby_mean`.

⚠️ **La moyenne traite des degrés ordinaux comme un intervalle.** La littérature le fait
pour les indicateurs de paysage ; c'est un résumé, pas une mesure.

`hemeroby_mean` est écrit `NA` sous `--hemeroby-min-coverage` (défaut **75 %**, un choix
énoncé, pas une valeur mesurée). Sans cette garde, une cellule à 38 % non résolue livrerait
une moyenne calculée sur 62 % de sa surface, lue comme comparable à 2015 calculée sur 95 %.

**Conséquence mesurée, à ne pas contourner.** Part de la surface qui franchit le seuil :

| Année | Aire retenue |
|---|---|
| 1960 | 57,4 % |
| 2015 | **99,1 %** |
| 2019 | 47,0 % |

Les années qui perdent la moitié de leur surface perdent la moitié **forestière**. Leur
moyenne porte donc sur les plaines agricoles et sort mécaniquement plus haut : 4,12 en
1960 et 4,03 en 2019 contre 3,57 en 2015. **Ces trois nombres ne se comparent pas entre
eux** — l'écart mesure la couverture, pas l'histoire. `trajectory_changes` porte
`hemeroby_comparable`, plus strict que `comparable` : il exige aussi que les deux années
retiennent au moins 95 % de leur surface.

### Contrôle de vraisemblance

Le mode d'échec énoncé d'avance était : si la table est inversée, les pays denses
sortiront *bas*. Mesuré sur 2015, moyenne pondérée par l'aire :

Danemark 4,46 · **Pays-Bas 4,45** · Belgique 4,28 · Allemagne 4,08 · France 3,95 ·
Espagne 3,94 · Autriche 3,47 · Suisse 3,37 · Finlande 2,90 · Suède 2,85 ·
**Norvège 2,18** · Islande 1,86.

La direction est correcte.

## Hiérarchie des sources

| Rôle | Source | Règle |
|---|---|---|
| Partition et trajectoire principales | HILDA+ v2 | Source prioritaire, annuelle, 1960–2020 dans la publication ; 1960–2019 est actuellement présent localement |
| Gestion forestière | Lesiv et al. | Remplace uniquement la part forêt HILDA en 2015 ; ne s'ajoute pas à celle-ci |
| Diagnostic annuel des herbages | Global Pasture Watch (GPW) | Croisé uniquement avec HILDA `33` et `55` ; ne modifie pas la partition principale |
| Mesure physique du bâti | WSF3D BuildingFraction | Colonne auxiliaire 2015 ; ne remplace pas automatiquement la classe urbaine HILDA |

Anthromes n'est pas une source primaire ici, car sa typologie incorpore la population.
BII reste une mesure séparée de condition écologique, et non une part de surface.

La comparaison HILDA `11` / WSF3D est une **calibration, pas un test d'accord** : la
classe urbaine HILDA couvre l'emprise urbaine entière (voirie, jardins, friches
interstitielles), la fraction WSF3D ne couvre que l'empreinte des bâtiments. La première
doit dépasser la seconde partout ; l'écart est la quantité informative, pas le désaccord.

## Reclassification principale

| Groupe | Codes HILDA+ v2 |
|---|---|
| `built_up` | `11` urban |
| `domesticated` | `22` annual crops, `23` tree crops, `24` agroforestry, `33` pasture/rangeland |
| `wild` | `55` unmanaged grass/shrubland, `66` sparse/no vegetation |
| `unresolved_forest` | `40–45` forest, tant que Lesiv n'est pas appliqué |

Le code `77` (eau) est exclu du dénominateur terrestre, comme `00` (océan) et `99`
(NoData). Cette règle évite de déclarer arbitrairement sauvages les réservoirs et cours
d'eau gérés. HILDA ne fournit pas une classe distincte pour les wetlands ni une
séparation naturel/géré de l'eau : une extension aquatique devra donc former un module
explicite, pas une attribution silencieuse.

Corollaire de l'exclusion de l'eau : dans une cellule majoritairement lacustre ou
côtière, les pourcentages portent sur une surface terrestre très petite. `land_area_m2`
est écrit dans chaque sortie pour cette raison — une cellule dont la part terrestre est
marginale ne doit pas être lue comme les autres.

## Jointure Lesiv en 2015

Dans les pixels HILDA `40–45` uniquement :

- Lesiv `11` → forêt `wild` ;
- Lesiv `20`, `31`, `32`, `40`, `53` → forêt `domesticated` ;
- Lesiv `0`, NoData ou autre code → forêt `unresolved`.

Les proportions Lesiv sont d'abord ramenées à la grille native HILDA, puis agrégées sur
la grille cible à aire égale. Cela conserve les mélanges sous-pixel sans compter deux
fois la forêt.

> **Décision ouverte n° 1.** Appliquer ce découpage à 2015 seulement, ou le projeter sur
> les autres années comme hypothèse statique explicitement étiquetée. C'est la décision
> qui commande le livrable : sans elle, la section « Ce que le produit dit » ci-dessus
> reste vraie. Le choix n'est pas tranché ici et le script ne le tranche pas non plus.

Le raster est maintenant sur le disque : `data_raw/biosphere/lesiv_2015/FML_v3-2_with-colorbar.tif`,
1 605 739 600 o, MD5 `23e1e0f247e0461b348d8cb9b95c8a6f` conforme à celui annoncé par
Zenodo. Licence CC-BY-4.0. Il n'est pas versionné dans le dépôt git.

**Ce que `wild` veut dire une fois Lesiv appliqué.** La légende source (`legend.xlsx`,
relevée dans le README du dossier) range trois sous-cas sous la classe `11`, et deux
comportent une présence humaine ou une perturbation : forêt non perturbée mais avec
**routes, maisons ou petits champs dans les 500 m**, et forêt perturbée naturellement
(incendie, chablis, insectes). `11` signifie donc « aucune signature de gestion dans le
pixel de 100 m », pas « aucune présence humaine » et pas « forêt intacte ». Symétriquement,
`20` absorbe les forêts semi-naturelles « visuellement très proches des forêts en
régénération naturelle ». La frontière `11`/`20` est un jugement d'interprète sur imagerie,
pas une mesure — et cette restriction doit figurer sur toute carte `wild` qui s'appuie
dessus.

### Une troisième voie, mesurée : l'histoire HILDA

Les codes forêt `40`–`45` sont **botaniques** (type de feuille, phénologie) et ne portent
aucune information de gestion : une plantation d'épicéas en rotation courte et une vieille
forêt non exploitée sont toutes deux `41`. Ils ne peuvent donc pas partager wild de
domesticated.

Mais HILDA porte autre chose que nous n'utilisons pas : soixante états annuels. Une
parcelle qui était culture en 1960 et forêt en 2015 a été transformée dans la fenêtre
d'observation, quel que soit son type de feuille — et *ça*, HILDA le sait vraiment.

Mesuré par [`scripts/5c_diagnose_forest_history.R`](scripts/5c_diagnose_forest_history.R),
règle de lecture écrite avant la mesure (< 10 % : sans intérêt ; ≥ 25 % : matériel ;
entre les deux : à câbler mais non décisif) :

| | 1960 | 2015 |
|---|---|---|
| Forêt | 1 493 385 km² | 1 790 444 km² (38,1 % des terres) |
| dont non-forêt à l'autre date | — | **438 795 km²** |
| Forêt aux deux dates | | 1 351 649 km² |
| Forêt perdue 1960→2015 | | 141 736 km² |

**S = 24,51 % de la surface forestière 2015, soit 9,33 pp des terres.** Verdict contre la
règle : **entre 10 et 25 %, à câbler mais non décisif seul** — 0,49 point sous le seuil
« matériel ». Comme S est une borne inférieure par construction (deux bornes temporelles
seulement : forêt → culture → forêt revient comme « stable »), la vraie part est plus
haute, et une valeur si proche du seuil sur une statistique biaisée vers le bas ne permet
pas de conclure dans un sens ou dans l'autre. C'est une raison de mesurer mieux, pas de
choisir la branche qui arrange.

Ce que ça donnerait : toute forêt ayant changé de classe depuis 1960 sortirait
d'`unresolved` vers `domesticated`, sans Lesiv. La forêt stable sur 60 ans y resterait —
HILDA ne peut pas dire si elle est exploitée. **Condition préalable** : le churn du 13 août
(voir « Limites connues »). Un test « a changé de classe depuis 1960 » non filtré compte
les excursions ≤ 2 ans comme des transformations. Il faut la version persistante
(classe différente et stable ≥ 3 ans) avant d'en tirer une partition.

**Corroboration au passage.** Ce diagnostic donne la forêt 2015 à 38,1 % des terres, contre
`pct_unresolved` = 38,09 % dans `trajectory_summary_10km.csv`, et un gain net de forêt de
+6,3 pp contre `delta_pct_unresolved_pp` = +6,25. Les deux chiffres sortent de chaînes de
calcul entièrement différentes — pondération par l'aire des cellules à 0,01° en WGS84 d'un
côté, indicateurs binaires projetés en EPSG:3035 puis agrégés à 10 km de l'autre. C'est le
premier recoupement externe du pipeline, et il passe. Les surfaces terrestres totales
diffèrent en revanche de 1,3 % (4 702 888 contre 4 764 168 km²), écart attribué au
traitement des cellules côtières partielles, non vérifié.

## GPW dans la trajectoire

Le manifeste GPW fournit un raster annuel de classe dominante et ses codes explicites.
Dans HILDA `33` + `55`, le pipeline calcule :

- `pct_gpw_cultivated_grass` ;
- `pct_gpw_natural_semi_grass` ;
- `pct_gpw_open_shrub` si cette classe existe ;
- `pct_grass_conflict` = HILDA `55` × GPW cultivated ;
- les confirmations HILDA `33`/`55` et la part sans validation GPW.

HILDA reste prioritaire : HILDA `33` × GPW natural/semi-natural reste `domesticated`,
mais est identifié comme rangeland moins intensif. Les diagnostics GPW ne sont jamais
additionnés à `pct_wild`, `pct_domesticated` ou `pct_built_up`.

> **Décision ouverte n° 2.** En l'état, aucun résultat GPW ne peut modifier la partition :
> la règle « HILDA reste prioritaire » n'a pas de mode d'échec, et le diagnostic est donc
> décoratif. Il manque le seuil écrit d'avance : à partir de quelle valeur de
> `pct_grass_conflict`, sur quelle fraction de cellules, cesse-t-on de faire confiance à
> HILDA `55` ? Tant que ce seuil n'est pas fixé, présenter les colonnes GPW comme une
> description, pas comme une validation.

Architecture temporelle :

- 1960–1999 : HILDA seul ;
- 2000–2019 avec les fichiers locaux actuels : HILDA + GPW si le manifeste est rempli ;
- 2015 : découpage forestier Lesiv si le raster est fourni ;
- 2020 : possible après ajout du raster HILDA 2020 ;
- 2021–2022 (GPW stable) et 2023–2024 (GPW v2-beta) : diagnostic des herbages seulement,
  pas de partition complète sans prolongement HILDA.

## Entrées

Déjà présentes :

- `data_raw/biosphere/hilda_plus_v2/states_wgs84/` : 60 états HILDA, 1960–2019 ;
- `../Technosphere/data_processed/eu_fraction_wsf3d_3km.tif` : fraction physique bâtie auxiliaire.

À ajouter manuellement :

- Lesiv : voir `data_raw/biosphere/lesiv_2015/README.md` ;
- GPW : voir `data_raw/biosphere/global_pasture_watch/README.md`

⚠️ Ces deux README ne sont **pas** dans le dépôt git : `data_raw/` est exclu par principe, et
un lien markdown vers eux ne peut donc pas résoudre — c'est ce qui a fait échouer le contrôle
`structure-and-syntax` du dépôt. Ils vivent à côté des données, sur le disque. La provenance
versionnée — URL, MD5, licence, table des classes — est dans `docs/data-sources.md`.
  et remplir `gpw_manifest.csv` à partir du modèle.

Les téléchargements globaux ne sont pas lancés implicitement : le raster Lesiv fait
environ 1,6 Go et chaque GeoTIFF annuel GPW v2-beta environ 16 Go. Pour un traitement
régional, préparer de préférence des COG découpés à l'emprise d'étude.

## Exécution

Depuis n'importe quel dossier, avec R 4.5.3 installé localement :

```powershell
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' `
  'Feature explorations/Biosphere/scripts/5_build_wild_domesticated_built.R' `
  --years=2015 --grid-km=10
```

Trajectoire HILDA locale complète :

```powershell
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' `
  'Feature explorations/Biosphere/scripts/5_build_wild_domesticated_built.R' `
  --years=1960:2019 --grid-km=10
```

Avec Lesiv et GPW — **`--overwrite` est obligatoire** si ces années ont déjà été
calculées sans raffinement :

```powershell
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' `
  'Feature explorations/Biosphere/scripts/5_build_wild_domesticated_built.R' `
  --years=2000:2019 --grid-km=10 --overwrite `
  --lesiv='C:/data/FML_v3-2_with-colorbar.tif' `
  --gpw-manifest='Feature explorations/Biosphere/data_raw/biosphere/global_pasture_watch/gpw_manifest.csv'
```

Sans `--overwrite`, le script sautait auparavant l'année en silence et laissait sur le
disque le résultat non raffiné tout en signalant un succès. Il compare désormais les
raffinements demandés aux drapeaux `lesiv_used` / `gpw_used` / `wsf3d_aux_used` de la
ligne QA existante : il ne saute que si l'année porte déjà ces raffinements, et s'arrête
avec une erreur nommant les manquants sinon. Si aucune ligne QA n'existe pour l'année, il
refuse plutôt que de deviner.

Le défaut opérationnel est l'Europe en EPSG:3035 avec une grille de 10 km et un
intermédiaire égal-aire de 1 km. Une grille mondiale de 10 km en Eckert IV est également
paramétrée ; elle est beaucoup plus coûteuse en espace temporaire :

```powershell
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' `
  'Feature explorations/Biosphere/scripts/5_build_wild_domesticated_built.R' `
  --years=2015 --grid-km=10 --extent=-180,-90,180,90 `
  --target-crs=ESRI:54012 `
  --target-extent=-18000000,-9000000,18000000,9000000 --mask=none
```

La demande initiale de Denis mentionne 10 × 10 km ; les autres couches Layer A utilisent
parfois 30 km. Le même script accepte `--grid-km=30`, ce qui permet de comparer les deux
résolutions sans changer les règles de classification.

## Sorties

`data_processed/wild_domesticated_built/` contient trois sous-dossiers :

- `rasters/wild_domesticated_built_<année>_<grille>km.tif` : un GeoTIFF multibande par année ;
- `tables/wild_domesticated_built_cells_<année>_<grille>km.csv` : `cell`, `x`, `y`, les
  pourcentages, `land_area_m2` et les surfaces en m² ;
- `tables/trajectory_summary_<grille>km.csv` ;
- `tables/trajectory_changes_<grille>km.csv` ;
- `tables/qa_<grille>km.csv` ;
- `tables/run_config.csv`, qui conserve les entrées et la règle appliquée à l'eau ;
- `maps/` : voir plus bas.

`_terra_tmp/` est le scratch de terra ; il peut être supprimé entre deux exécutions.

Dans `trajectory_changes`, chaque ligne porte `from_support`, `to_support` et
`comparable`. Un écart entre deux années construites sur des sources différentes est un
**changement de méthode, pas un changement de terrain** : avec Lesiv appliqué à la seule
année 2015, toute ligne touchant 2015 déplace de la forêt hors d'`unresolved` pour cette
seule raison, et sort donc avec `comparable = FALSE`. Les colonnes
`rate_*_pp_per_decade` normalisent les écarts, les lignes pouvant couvrir 55 ans ou 4.

## Contrôles

**C0 — identité, pas contrôle.**

```text
pct_wild + pct_domesticated + pct_built_up + pct_unresolved = 100
```

Cette égalité est vraie *par construction* : `unresolved` est défini comme le résidu
`valid − wild − domesticated − built` et le dénominateur est la somme des quatre. Elle
est mesurée à 3 × 10⁻¹⁴ point de pourcentage, c'est-à-dire du bruit flottant. Elle est
conservée parce qu'elle attraperait encore une faute de masque ou d'arithmétique, mais
**elle ne peut pas échouer pour une raison qui rendrait la partition fausse** et ne doit
jamais être présentée comme une preuve que la partition est juste. Colonnes
`identity_max_abs_sum_error_pct`, `identity_mean_abs_sum_error_pct`.

**C1 — routage.** Tout code de `VALID_HILDA` doit atteindre exactement un des groupes
built / domesticated / wild / forest. Sinon il tombe silencieusement dans le résidu et
gonfle `unresolved` sans que rien ne le signale. Avant Lesiv, `unresolved` *est*
l'indicateur forêt ; après Lesiv, `unresolved = forêt × (1 − classified)`, ce qui est
exactement `unresolved_forest`. Les deux couches doivent donc être égales dans les deux
cas. Colonnes `routing_max_gap_pp`, `routing_cells_over_noise`, `routing_ok`.

Deux seuils, parce que la première version en avait un seul et qu'il était **infaisable** :
les rasters sont écrits en `FLT4S`, dont l'ULP vaut ≈ 3,8 × 10⁻⁶ pp aux magnitudes en jeu,
si bien qu'une tolérance de 10⁻⁶ pp ne pouvait pas être satisfaite.

- `ROUTING_NOISE_PP = 10⁻⁵` : plancher de précision de stockage. Les cellules au-dessus
  sont **comptées**, pas mises en échec.
- `ROUTING_FAIL_PP = 10⁻³` : seuil de verdict. Une classe réellement non routée produit
  **25,4 pp** dans `tests/test_wild_domesticated_built.R` (partie 3), donc la marge reste
  de quatre ordres de grandeur.

Ce test a un mode d'échec démontré, pas supposé : la partie 3 de la suite patche une copie
du pipeline pour laisser une classe valide non routée, et vérifie que C1 échoue à 25,4 pp
**pendant que C0 reste sous 10⁻⁵**. C'est la preuve que les deux contrôles ne mesurent pas
la même chose.

**C4 — fermeture des degrés.** `Σ pct_hemeroby_1..6` doit égaler la part résolue, soit
`100 − pct_unresolved`. Échoue si une classe n'a pas de degré, ou en a deux. Même
calibrage à deux niveaux que C1. Colonnes `hemeroby_max_closure_gap_pp`,
`hemeroby_closure_cells_over_noise`, `hemeroby_closure_ok`.

Mode d'échec démontré lui aussi : la partie 4 de la suite retire les pâturages de la table
des degrés dans une copie du pipeline et vérifie que **C4 échoue à 26,4 pp pendant que C1
reste vert** — les deux contrôles répondent bien à deux questions différentes. Ce test a
d'ailleurs trouvé un défaut avant même de tester ce qu'il visait : avec une entrée de degré
vidée, le pipeline **plantait** au lieu de produire une couche vide, ce qui aurait masqué
quel contrôle aurait dû se déclencher.

**C2 — fermeture des surfaces.** Surface terrestre HILDA totale rapportée à l'aire
planimétrique des polygones d'étude dans la même projection équivalente. Le rapport doit
être **inférieur à 1** (HILDA retire les eaux intérieures que les polygones incluent) et
proche de 1. Une CRS erronée, une emprise tronquée ou un masque cassé le déplacent
franchement — et C0 n'en verrait rien. Colonnes `land_area_m2`,
`study_polygon_area_m2`, `land_over_polygon_ratio`. `NA` quand `--mask=none`.

Observé sur l'Europe à 10 km, EPSG:3035, emprise `-25,34,45,72` : **0,98458**, identique
à 10⁻⁸ près pour 1960, 2015 et 2019 — normal, puisque la surface terrestre valide ne
change pas d'une année à l'autre, seule sa composition change. Les 1,54 % manquants sont
les eaux intérieures et le NoData que les polygones incluent et que HILDA retire. Règle de
lecture, calibrée sur cette emprise et cette projection seulement : un rapport ≥ 1 est
impossible et signale une faute ; un écart de plus de 1 point par rapport à 0,985 sur la
même emprise signale un changement de géométrie à examiner avant de lire les cartes. Sur
une autre emprise, il faut recalibrer plutôt que réutiliser ce chiffre.

**C3 — bornes de fraction.** Une fraction indicatrice moyennée ne peut sortir de [0, 1]
que par une faute de rééchantillonnage. Le script continue de la ramener dans l'intervalle,
mais émet désormais un avertissement nommant la couche et les valeurs observées, au lieu
de réparer en silence.

Aucun de ces contrôles ne confronte la partition à une **source indépendante**. C'est le
manque principal : une comparaison de `pct_built_up` et `pct_domesticated` 2015 avec
CORINE, ou de la composition 2019 avec ESA WorldCover 2020, reste à faire et serait le
premier vrai test externe.

## Limites connues

**Défaut ouvert : C1 échoue sur trois cellules, cause non établie (2026-08-26).** Sur le
run 2015 avec Lesiv, C1 relève 142 cellules au-dessus du plancher float32 sur 52 244. 139
d'entre elles sont exactement à 3,815 × 10⁻⁶ pp, soit un ULP de float32 : c'est du
stockage, pas un défaut. Les trois autres sont à **0,0495 / 0,0066 / 0,0026 pp**, et font
échouer le contrôle.

Ce qui est établi :

- les trois cellules sont **contiguës sur une même ligne**, en Norvège centrale
  (≈ 10 °E, 62,75 °N ; cellules 39356–39358 en EPSG:3035) ;
- leur fraction terrestre vaut 1 : ce ne sont pas des slivers côtiers ;
- l'écart **change de signe** entre elles, donc pas de biais directionnel ;
- l'écart n'apparaît **pas** sans Lesiv.

Deux hypothèses ont été formulées puis **réfutées par la mesure**, et sont consignées pour
que personne ne les reprenne :

1. *Amplification par un dénominateur terrestre faible.* Réfutée : les cellules concernées
   sont pleinement terrestres (fraction 1,0).
2. *Non-déterminisme de la chaîne `project()` / `aggregate()`.* Formulée après que deux
   exécutions identiques eurent donné 0,0495 pp puis 4,30 × 10⁻⁶ pp. Réfutée par une
   troisième exécution : elle redonne **0,0495407181764942 pp**, bit pour bit identique à
   la première, `land_area_m2` compris. Deux runs sur trois coïncident exactement.

Reste donc une anomalie de second ordre non résolue : **le run n° 2 diffère des runs 1 et 3
alors que les entrées et le script sont identiques**, y compris sur `land_area_m2`
(4 764 168 108 482 contre 4 764 168 054 980 m², soit 1,1 × 10⁻⁸ en relatif). Piste non
testée : le découpage en chunks de terra dépend de la mémoire disponible, ce qui change
l'ordre d'accumulation en virgule flottante. Aucune cause n'est retenue tant qu'elle n'est
pas testée.

**Le seuil de C1 n'a pas été déplacé pour faire passer le contrôle.** Le faire reviendrait
à transformer un test qui échoue en test qui ne peut pas échouer, ce qui est précisément
le défaut que ce contrôle existait pour éviter. `routing_ok = FALSE` est donc l'état
actuel et assumé, et le message d'avertissement du script énonce l'observation sans
nommer de cause.

Portée : 3 cellules sur 52 244, écart maximal 0,05 pp. Immatériel pour toute carte et pour
tous les chiffres agrégés de ce document.

**Churn de reconstruction HILDA.** Le test du 13 août 2026
([`hilda_flicker_test_2026-08-13.md`](hilda_flicker_test_2026-08-13.md)) a établi, contre
une règle écrite avant mesure, que **62,6 % des changements comptés par HILDA+ v2 sont des
excursions de ≤ 2 ans qui reviennent à leur classe de départ** (critère C2 : 69,61 % et
66,47 % contre un seuil d'échec à 10 %). Le critère C1 du même test passe : ce n'est pas
un artefact d'arrivée des satellites, mais une propriété de la procédure d'allocation de
changement elle-même, aussi forte en 1960–1981 qu'après 2000.

Ce que cela implique ici **a maintenant été mesuré** (2026-08-27). Le churn du 13 août
portait sur des transitions *par pixel* ; le présent produit agrège des *parts de surface*,
où un aller-retour A → B → A se compense largement. Les deux issues étaient plausibles,
d'où un test dédié : [`scripts/5e_diagnose_area_share_churn.R`](scripts/5e_diagnose_area_share_churn.R),
**règle de lecture écrite avant la mesure**, fenêtre 2000–2019 annuelle, HILDA seul (Lesiv
coupé — sinon un changement de source à l'intérieur de la fenêtre se lirait comme du churn ;
le script refuse tout run dont `temporal_support` n'est pas `hilda_only`).

| Statistique | Mesure | Seuils écrits d'avance | Verdict |
|---|---|---|---|
| S — inversions de signe, poolé sur 72 deltas non nuls | **0,3750** | PASS ≤ 0,15 · FAIL ≥ 0,35 | **FAIL** |
| R — brut / net, composantes éligibles (\|net\| ≥ 1 pp) | 1,90 · 1,31 · 1,14 | PASS ≤ 1,5 · FAIL ≥ 3,0 | INCONCLUSIVE |
| **Combiné** | | FAIL si l'une des deux échoue | **FAIL** |

Par composante : `wild` S = 0,611 / R = 1,90 ; `domesticated` 0,500 / 1,31 ; `built_up`
0,111 / non éligible (net = +0,17 pp, sous le plancher de 1 pp) ; `unresolved` 0,278 / 1,14.

**Conséquence, à appliquer :** ne pas écrire de phrase de la forme « X points de pourcentage
par décennie » à partir d'écarts entre **années consécutives**. `rate_*_pp_per_decade` reste
calculé dans `trajectory_changes_10km.csv`, mais ne doit pas être publié tel quel.

**Les deux statistiques ne pointent pas dans le même sens, et il faut le dire.** S = 0,375
est aux trois quarts du chemin vers le bruit pur (0,5) : le signe s'inverse souvent. Mais R
entre 1,14 et 1,90 dit que le mouvement **ne s'annule pas majoritairement** — pour
`domesticated`, 4,03 pp de mouvement brut pour 3,06 pp de net. La lecture cohérente est
« petites excursions annuelles posées sur une vraie tendance ». La règle combinée tranche
quand même FAIL, et **elle n'a pas été réécrite après coup**. S ne dépasse son seuil que de
0,025 : c'est une raison de mesurer mieux, pas de déplacer la barre.

**Ce que ce test ne couvre pas.** Il porte sur les deltas entre années consécutives. La carte
1960→2019 (`space_change_1960_2019_10km.png`) est une différence entre deux bornes, donc une
autre quantité : ce verdict ne la blanchit pas et ne la condamne pas.

## Cartes PNG

Le script reproductible [`scripts/5b_map_wild_domesticated_built.R`](scripts/5b_map_wild_domesticated_built.R)
transforme les GeoTIFF annuels en cartes comparables :

```powershell
& 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' `
  'Feature explorations/Biosphere/scripts/5b_map_wild_domesticated_built.R'
```

Les sorties sont écrites dans `data_processed/wild_domesticated_built/maps/` : planche
complète des quatre composantes, cartes individuelles, changements 1960–2019 et
comparaison HILDA/WSF3D du bâti en 2015. Toutes les cartes temporelles conservent une
échelle fixe de 0 à 100 %.

## Deck de méthode

`wild_domesticated_built_method_deck.pptx` (19 diapos, anglais) explique la construction à
un lecteur qui ne lira pas ce document : 14 diapos de corps, 5 d'annexe (contrôles, défaut
ouvert, churn, décisions ouvertes, sources).

La diapo 5 porte la **table de reclassification complète** — chaque code HILDA `11`…`99` et
chaque code Lesiv `11`…`53` avec son groupe, libellés transcrits des README source — et la
diapo 7 donne les **quatre** formules, pas seulement celle de `wild`. Sans ça les codes
apparaissaient sur trois diapos sans légende, et `domesticated` / `built_up` n'avaient qu'une
phrase en prose là où `wild` avait une formule.

```powershell
python 'Feature explorations/Biosphere/scripts/6_make_method_deck.py'
```

⚠️ **Ni le `.pptx` ni son script générateur ne sont versionnés dans le dépôt git.** Le
`.gitignore` exclut les documents Office, et le choix a été fait de ne pas y déroger. Les
deux vivent uniquement dans le dossier de travail OneDrive — donc le deck n'a pas
d'historique, et un collègue qui clone le dépôt ne l'aura pas. Le présent document reste la
référence versionnée de la méthode.

**Aucun pourcentage n'y est tapé en dur** : le script relit `trajectory_summary_10km.csv`,
`qa_10km.csv`, `run_config.csv` et `area_share_churn_diagnostic.csv` au moment du build.
Seule exception, étiquetée comme telle dans le script et sur la diapo qu'elle alimente :
la colonne « 2015 sans Lesiv », qui exigerait un second run complet pour être recalculée.

## Sources

- HILDA+ v2.0 : <https://doi.org/10.1594/PANGAEA.974335>
- Lesiv et al. 2022 : <https://doi.org/10.1038/s41597-022-01332-3>
- Données Lesiv 2015 : <https://doi.org/10.5281/zenodo.5879022>
- GPW stable 2000–2022 : <https://doi.org/10.1038/s41597-024-04139-6>
- GPW v2-beta 2000–2024 : <https://doi.org/10.5281/zenodo.15646181>

## Révisions

- **2026-08-27** — Test de churn sur les **parts de surface** exécuté (`5e`, fenêtre
  2000–2019, HILDA seul) : **FAIL**, S = 0,3750 contre un seuil d'échec de 0,35 fixé avant la
  mesure. Interdiction de publier des « pp par décennie » entre années consécutives, consignée
  ci-dessus ; le seuil n'a pas été déplacé. Deck de méthode ajouté pour les collègues
  (`wild_domesticated_built_method_deck.pptx`, généré par `scripts/6_make_method_deck.py` —
  aucun des deux n'est versionné, voir la section « Deck de méthode »).
- **2026-08-26 (4)** — Structure emboîtée : `pct_anthropogenic` ajouté, libellé de carte
  passé à `Domesticated (non-built)`. Gradient d'hémérobie 1–6 ajouté (parts par degré,
  moyenne, couverture, masque à 75 %), avec le contrôle C4 et sa partie de test négative.
  Degré 7 non attribué faute de seuil justifié. Carte du gradient. Contrôle de
  vraisemblance par pays : direction confirmée.
- **2026-08-26 (3)** — Cartes régénérées. `5b` étiquette désormais chaque panneau avec sa
  source (`2015 (HILDA + Lesiv)` contre `1960 (HILDA only)`) et porte un `CAUTION` en
  légende quand les panneaux ne partagent pas la même source : sans ça la planche
  `Unresolved` se lisait comme un effondrement puis un rebond. Fiche d'acquisition Lesiv
  ajoutée à `docs/data-sources.md` du dépôt, `data_raw/` n'étant pas versionné.
- **2026-08-26 (2)** — Raster Lesiv téléchargé et vérifié ; 2015 recalculé avec le
  découpage forestier : `unresolved` passe de 38,09 à 4,74 %, `domesticated` de 40,72 à
  71,61 %. Seuil de C1 recalibré après un échec sur ce run — il était sous la précision
  de stockage float32, donc infaisable. Trois cellules en écart inexpliqué consignées
  comme défaut ouvert. Légende Lesiv relevée à la source et restriction de la classe `11`
  documentée.
- **2026-08-26 (1)** — Contrôles C1/C2/C3 ajoutés ; C0 requalifié en identité. Arrêt
  explicite quand un raffinement est demandé sur une année déjà calculée sans
  `--overwrite`. `comparable` et `rate_*_pp_per_decade` ajoutés à `trajectory_changes`.
  Limite de churn HILDA reportée depuis le test du 13 août. Diagnostic d'histoire
  forestière (`5c`) : S = 24,51 %. Deux décisions de méthode marquées ouvertes.
- **2026-08-25** — Première version du workflow et du script.
