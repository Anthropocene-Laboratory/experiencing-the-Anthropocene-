# Quelles variables combiner pour une typologie d'exposition européenne ?

Note méthodologique — 2026-07-29
Statut : **exploratoire** (cf. `Feature explorations/CLAUDE.md` : rien ici n'est
un Core set ; la Phase 2 de classement n'a pas eu lieu).
Périmètre : Layer A uniquement, Europe, EPSG:3035.

Convention de lecture : les affirmations marquées **[V]** sont vérifiées dans une
source citée ou dans un fichier du workspace ; celles marquées **[S]** sont des
suppositions de ma part, à tester avant usage.

---

## 0. Ce que j'ai lu

| Source | Ce que j'en tire |
|---|---|
| `Feature library/Merged_datasets.xlsx` (5 onglets, lecture intégrale) | §2 — audit du catalogue |
| `AGENTS.md` | règle des couches, 11 champs obligatoires, décisions ouvertes |
| `Feature explorations/Analysis/exposure_archetypes_notes.md` | contraintes empiriques déjà établies (support 30 km, PC1, coverage, ρ, choix de k) |
| Littérature (14 travaux cités, §1) | critères de sélection, traitement de la redondance, tests falsifiables |

---

## 1. Synthèse de littérature

### 1.1 Exposome spatial / external exposome

Le champ le plus proche de ce que fait le projet. L'*external exposome* consiste
à assigner à chaque individu (ou à chaque adresse) un vecteur de dizaines
d'expositions environnementales, puis à en chercher la structure.

**[V]** Le travail de référence pan-européen est de Hoogh et al. (2025),
*A Europe-wide characterization of the external exposome: a spatio-temporal
analysis*, Environment International 200 : 33 facteurs exposomiques
(physico-chimiques, bâti, social, alimentaire) modélisés à fine résolution sur
l'Europe, 2000–2020, avec analyse explicite de leurs interrelations spatiales et
temporelles. DOI : 10.1016/j.envint.2025.109542.

Dans EXPANSE, les expositions sont regroupées en **trois domaines** — pollution
de l'air (PM2.5, NO₂, black carbon, ozone estival) ; environnement bâti/terrestre
(NDVI, surfaces imperméables, distance à l'eau) ; température de l'air (moyennes
et écarts-types saisonniers) — puis **chaque domaine est résumé séparément par
ACP, avec l'objectif d'expliquer ≥ 80 % de sa variance interne**
(de Hoogh et al. 2024, *Socioeconomic Inequalities in the External Exposome in
European Cohorts*, Environ. Sci. Technol. ; Rodopoulou et al. 2024, *External
exposome and all-cause mortality in European cohorts*, PMC11165119).

1. **Critère de choix des variables** : *conceptuel d'abord, disponibilité
   ensuite*. Les domaines sont posés a priori (air / bâti / climat), et à
   l'intérieur de chaque domaine on prend ce qui est modélisable de façon
   homogène sur toute la zone. Le critère statistique n'intervient **pas** dans
   le choix des variables, seulement dans leur agrégation.
2. **Traitement de la redondance** : l'ACP est faite **à l'intérieur** de chaque
   domaine, jamais entre domaines. C'est un choix méthodologique fort : il
   accepte que les composantes d'un même domaine soient colinéaires (c'est même
   ce qui les définit comme un domaine) et **protège la comparabilité entre
   domaines** de la domination du domaine le mieux mesuré. Agier et al. (2016,
   *Environ. Health Perspect.* 124(12), PMC5132632) montrent par simulation sur
   237 covariables corrélées que ni ENET, ni sPLS, ni GUESS, ni DSA ne dominent
   uniformément l'ExWAS naïf : **la corrélation entre expositions reste un
   problème non résolu du champ**, pas une difficulté technique déjà réglée.
3. **Test qui pouvait échouer** : oui, et il est précis — si une ACP de domaine
   n'atteint pas 80 % de variance avec un petit nombre de composantes, le domaine
   n'est pas résumable et doit être éclaté. Le test échoue quand le domaine est
   mal construit. En revanche, **l'existence même de « domaines » n'est jamais
   testée** : aucune analyse ne pouvait conclure que la partition air / bâti /
   climat était la mauvaise. C'est une limite du champ, pas de ces auteurs.

**Ce que ça implique ici** : la structure « une ACP par sphère, pas une ACP
globale » est directement transposable aux sphères A1–A4, et elle attaque
frontalement l'échec mesuré (PC1 = 65,5 % sur bâti+lumière+PM2.5). Ces trois
variables sont, en langage EXPANSE, **deux domaines qu'on a mélangés** —
air et bâti — dont l'un est presque entièrement prédit par l'autre à ce support.

### 1.2 Indices d'environnement multiple

**[V]** Richardson, Mitchell et al. (2010), *Developing summary measures of
health-related multiple physical environmental deprivation for epidemiological
research* (Environment and Planning A / Univ. Edinburgh Research Explorer),
construisent le **Multiple Environmental Deprivation Index (MEDIx)** : cinq
dimensions choisies parce qu'elles ont un lien *documenté* avec la santé —
pollution de l'air, climat froid, sites industriels, espaces verts, rayonnement
UVB — dont deux sont *bénéfiques* (verdure, UVB) et trois délétères. Le MEDIx a
été répliqué en Nouvelle-Zélande (Pearce et al. 2011, *Soc. Sci. Med.*,
PMID 21726927) et au Portugal (Ribeiro et al. 2015, *Eur. J. Public Health*
25(4):610).

**[V]** Côté institutionnel, le rapport AEE 22/2018 *Unequal exposure and unequal
impacts: social vulnerability to air pollution, noise and extreme temperatures in
Europe* croise trois expositions environnementales avec des indicateurs sociaux
au niveau NUTS — sans les fusionner en un indice unique.

1. **Critère de choix** : *conceptuel, adossé à une littérature santé*. Une
   variable entre dans MEDIx si un effet sanitaire lui est déjà attribué. Aucun
   critère de variance, aucune sélection par les données.
2. **Redondance** : traitée par **quantiles et somme**, pas par décorrélation.
   Chaque dimension est passée en rangs puis additionnée. Conséquence assumée :
   deux dimensions corrélées comptent deux fois. Le champ des indices composites
   accepte cela parce que le produit est un *score de sévérité*, pas une
   typologie — on ne lui demande pas de séparer des axes.
3. **Test qui pouvait échouer** : oui, mais externe et faible — MEDIx est validé
   par sa **corrélation avec la santé et la déprivation sociale**. Un MEDIx sans
   gradient de santé aurait indiqué un mauvais choix de dimensions. C'est
   falsifiable, mais ça teste la *pertinence sanitaire* de l'indice, jamais sa
   *structure interne*. **L'AEE 22/2018, lui, ne pose aucun test falsifiable** :
   il décrit des co-distributions.

**Ce que ça implique ici** : un indice additif est le bon produit quand on veut
une sévérité, et le mauvais quand on veut une typologie. Les deux ne se
distinguent pas par les variables mais par ce qu'on en fait ensuite (cf. §3, P4).

### 1.3 Classification géodémographique et typologies spatiales

**[V]** Vickers & Rees (2007) réduisent 41 variables de recensement à une
classification d'output areas (OAC) ; le champ a depuis documenté que
**les variables à distribution extrême dégradent le clustering** et que le nombre
de variables doit être tenu au minimum, au prix reconnu d'une description
appauvrie du quartier (Singleton & Longley 2024, *Environment and Planning B*,
DOI 10.1177/23998083241242913).

**[V]** Côté spatial : SKATER (single-linkage sous contrainte de contiguïté) et
REDCAP (six méthodes hiérarchiques régionalisantes, avec contiguïté d'ordre
complet) sont les standards, documentés et implémentés dans GeoDa/pygeoda
([GeoDa workbook](https://geodacenter.github.io/workbook/9c_spatial3/lab9c.html)).
Une comparaison sur données réelles trouve SKATER meilleur à grande taille
d'échantillon, REDCAP-Ward bon mais dégradé quand N croît
([arXiv 2209.11836](https://arxiv.org/pdf/2209.11836)).

**[V]** Les deux typologies spatiales institutionnelles les plus utilisées ne
sont **pas** obtenues par clustering : les **Local Climate Zones**
(Stewart & Oke 2012, *BAMS* 93:1879–1900) sont 17 classes *définies a priori*
par des propriétés de surface (hauteur/densité du bâti, perméabilité), validées
ensuite par des contrastes thermiques mesurés (> 5 K entre classes contrastées) ;
le **degré d'urbanisation (DEGURBA / GHS-SMOD)**, endossé par la Commission
statistique de l'ONU en 2020, classe des cellules de 1 km² par **seuils** de
densité, contiguïté et taille de population
([GHS-DUG User Guide](https://human-settlement.emergency.copernicus.eu/tools/GHS-DUG_User_Guide.pdf)).

1. **Critère de choix** : deux écoles opposées. Géodémographie = *statistique*
   (on prend beaucoup de variables et le clustering décide). LCZ/DEGURBA =
   *conceptuel et normatif* (les classes précèdent les données).
2. **Redondance** : la géodémographie la traite par standardisation + réduction
   du nombre de variables, et l'assume largement. LCZ/DEGURBA n'ont pas de
   problème de redondance parce qu'ils n'ont pas de clustering.
3. **Test qui pouvait échouer** : **LCZ est le meilleur exemple de tout ce
   corpus**. La classification est définie sur la *forme urbaine* et validée sur
   une variable *externe et non utilisée pour la construire* : la température
   mesurée. Si les classes n'avaient pas montré de contrastes thermiques, le
   schéma aurait été invalidé. La géodémographie, elle, se valide par
   **ground-truthing** (des relecteurs reconnaissent leurs quartiers,
   Vickers & Rees 2011) : c'est un test qui peut échouer, mais dont le critère
   est le jugement d'expert, pas une mesure.

**Ce que ça implique ici — le point le plus important de cette note.** LCZ montre
la seule forme de validation qui indicte vraiment une typologie : **une variable
tenue hors du clustering, sur laquelle les classes doivent se séparer.** C'est
exactement ce que Layer B rend possible ici, et pour une raison structurelle :
la règle « une variable Layer B n'entre jamais dans un clustering Layer A » est
d'ordinaire présentée comme une contrainte conceptuelle, mais elle **fabrique
mécaniquement un jeu de validation externe**. Un clustering Layer A dont les
archétypes ne se différencient sur *aucun* filtre B (richesse, âge, densité,
usage du temps) décrit peut-être une géographie, mais pas une géographie
d'exposition humaine.

### 1.4 Downscaling des limites planétaires

**[V]** Häyhä et al. (2016), *From Planetary Boundaries to national fair shares
of the global safe operating space — How can the scales be bridged?*
(Global Environmental Change, S0959378016300826), distinguent trois dimensions à
la descente d'échelle : **biophysique, socio-économique et éthique**, et montrent
qu'aucune ne se résout par les deux autres. Nykvist et al. (2013) avaient fait
l'application nationale pionnière (Suède) ; Ryberg et al. (2020), *Downscaling
the planetary boundaries in absolute environmental sustainability assessments —
a review* (J. Cleaner Prod., S0959652620333321), recense les méthodes
d'allocation.

1. **Critère de choix** : imposé par le cadre — ce sont les 9 variables de
   contrôle des limites planétaires, pas un choix libre.
2. **Redondance** : non traitée, et c'est cohérent : les limites sont posées
   comme des processus distincts par construction, jamais testés pour
   indépendance empirique.
3. **Test qui pouvait échouer** : **aucun test falsifiable au sens strict.**
   Le partage d'un budget global entre territoires dépend d'un principe d'équité
   (égal par habitant, grandfathering, capacité à payer) qui est un **choix
   éthique** : aucune donnée ne peut le contredire. Häyhä et al. le disent
   eux-mêmes en isolant la dimension éthique. **À dire explicitement si le projet
   veut mobiliser ce cadre : le downscaling produit des cartes normatives, pas
   des cartes testables.**

**Ce que ça implique ici** : l'exploration BII / limite planétaire biosphère
(74 % des Européens au-delà de la limite) relève de ce registre. C'est une
affirmation normative correctement sourcée ; elle ne fournit **pas** de test
capable d'indicter une typologie.

### 1.5 Validation du clustering

**[V]** Hennig (2007), *Cluster-wise assessment of cluster stability*,
Comput. Stat. Data Anal. 52(1):258–271
([PDF auteur](https://www.homepages.ucl.ac.uk/~ucakche/papers/clusta.pdf)) :
la stabilité s'évalue **cluster par cluster**, par la distribution bootstrap du
coefficient de Jaccard entre chaque cluster original et son plus proche
homologue dans les rééchantillons. Bandes de lecture de l'auteur : **≥ 0,85 =
hautement stable** ; ~0,6–0,75 = « il y a un motif dans les données, mais pas un
cluster net » ; **< 0,5 = dissous, à ne pas interpréter**. Implémenté dans
`fpc::clusterboot()`.

> **Correction à porter au dossier.** `exposure_archetypes_notes.md` attribue à
> Hennig 2007 le seuil « < 0,75 ⇒ pas un motif stable ». Le seuil de Hennig pour
> « hautement stable » est **0,85**, et 0,6–0,75 est décrit comme *motif présent
> mais pas cluster net*. Le k = 4 retenu (J = 0,95) passe très largement dans la
> lecture correcte comme dans l'autre ; **la conclusion ne change pas**, mais la
> citation doit être corrigée avant publication, et k = 3 (J = 0,68) devrait être
> décrit comme « motif sans cluster net » plutôt que comme un rejet franc. **[V]**

**[V]** Tibshirani, Walther & Hastie (2001), gap statistic : formalisation du
coude par comparaison de la dispersion intra-cluster à une distribution nulle de
référence. **[V]** Adolfsson, Ackerman & Brownstein (2019), *To cluster, or not
to cluster: an analysis of clusterability methods*, Pattern Recognition
([PDF](https://maya-ackerman.com/wp-content/uploads/2018/09/clusterability2017.pdf))
: les tests de *clusterabilité* précèdent logiquement le choix de k, et
Ackerman & Ben-David ont montré que **les différentes notions de clusterabilité
sont deux à deux incohérentes** — il n'existe pas de test unique de « il y a des
clusters ».

1. **Critère de choix des variables** : ce corpus n'en propose aucun. Il valide
   *après*, jamais *avant*. C'est précisément le trou dans lequel tombe une
   typologie construite sur des variables colinéaires.
2. **Redondance** : traitée uniquement de façon implicite (standardisation,
   distances). Aucune de ces méthodes ne détecte que les variables sont des
   proxys les unes des autres.
3. **Test qui pouvait échouer** : le bootstrap de Hennig, oui, franchement — un
   cluster instable est identifié comme tel. Le silhouette, **non**, et c'est le
   point contesté du champ : *découper un gradient unidimensionnel en tranches
   produit mécaniquement des tranches compactes et bien séparées*. Un silhouette
   élevé est donc compatible avec « il n'y a pas de typologie ». Le résultat
   mesuré ici (silhouette 0,46 sur un jeu à PC1 = 65,5 %, contre 0,273 sur le jeu
   admissible à PC1 = 50 %) est **une illustration empirique de cette critique,
   pas une anomalie** : le silhouette y est plus élevé là où la structure est la
   moins réelle.

### 1.6 Où le champ diverge, et ce qu'il accepte comme validation

| | Établi | Contesté |
|---|---|---|
| Choix des variables | La justification conceptuelle prime : aucun des travaux cités ne sélectionne les variables par leur variance | Faut-il beaucoup de variables (géodémographie) ou peu et théorisées (MEDIx, LCZ) ? Divergence non tranchée |
| Redondance | Elle doit être déclarée et mesurée | Comment la traiter : ACP par domaine (exposome) vs somme de rangs assumant le double comptage (indices) vs élagage (géodémographie) |
| Validation | Le silhouette seul ne valide rien ; la stabilité par bootstrap est le standard minimal | Existence même de « clusters » : pas de test de clusterabilité consensuel (Ackerman & Ben-David) |
| Validation forte | **Une variable externe non utilisée dans la construction** (le modèle LCZ) est la seule validation qui puisse indicter la typologie | Peu pratiqué hors LCZ |

---

## 2. Ce que contient réellement `Merged_datasets.xlsx` (audit)

Lecture intégrale des 5 onglets : `Layer A`, `Layer B`, `Layer C`, `Layer D`,
`Ambiguous - to classify`. En-têtes en ligne 4, 40 colonnes, **85 lignes-features
dans Layer A**. Cinq constats contraignent la suite. Tous **[V]**.

**(a) Layer A a six sous-domaines, pas quatre.** Outre A1–A4, l'onglet contient
`A5 — Individuality` (2 features : rythme de « modernisation » vécu ; exposition
individuelle à la connaissance d'autres parties de l'Anthropocène) et
`A6 — Economy` (13 features : PIB, dépendance aux marchés mondiaux pour
l'alimentation, économie de l'attention, location à vie, précariat, terres
privées inaccessibles, pénuries alimentaires…). Le brief de cette note ne les
mentionne pas. **A6 pose un problème de couche direct** : PIB (A6-b01) est en
Layer A alors que revenu/richesse est le filtre B2 ; ces deux lignes mesurent la
même chose dans deux rôles analytiques incompatibles.

**(b) Le catalogue est très majoritairement vide.** Taux de remplissage mesuré
sur les 85 lignes de Layer A :

| Champ | Lignes remplies / 85 |
|---|---|
| ID, Feature | 85 |
| Dataset nommé | 31 (+ 1 ligne déclarant explicitement « aucune source ouverte ») |
| Résolution spatiale, couverture, unité, mode temporel | 32 |
| Licence / accès, format, disponibilité | 27 |
| **Sphère, sous-domaine** | **8** |
| **Mode primaire, mode secondaire, directness** | **3** |
| Rôle analytique | 3 |
| Biais / caveat connu | 3 |
| Joinability | 8 |
| **Priority, Rank, Promotion, Inclusion, Feasibility, Anthropocenesque score, Metadata completeness** | **0** |

Conséquence opérationnelle : **le catalogue ne peut pas, en l'état, fournir le
tag mode-d'expérience × directness que le brief demande par variable.** Trois
lignes sur 85 le portent (A1-b09, A1-b10, A1-b11 — les trois entrées canicule).
Les tags que je donne au §3 sont donc **[S]**, dérivés des définitions de
`AGENTS.md`, et doivent être validés en Phase 4, pas lus comme du catalogue.

**(c) Trois des six features actuellement clusterisées n'existent pas dans le
catalogue.** Recherche exhaustive sur les 5 onglets : aucune occurrence de
« PM2.5 », « UTCI », « CAMS », « ERA5 », ni de ligne « cropland fraction ».
`A1-b08 Heatwave exposure` existe mais **sans dataset**. Autrement dit, le jeu
retenu (bâti WSF3D, Falchi, PM2.5, UTCI ≥ 32 °C, TX > P90, cropland) est traçable
au catalogue pour **deux** variables sur six (T-002 WSF3D, T-012 Falchi). C'est
un écart de traçabilité à combler avant toute publication — pas un défaut de
l'analyse, mais le catalogue ne peut pas actuellement servir de source de vérité
sur ce qui a été utilisé.

**(d) Doublons inter-couches déjà présents dans le classeur.** `A3-001 Population
density` (Layer A) vs `B1-005 Local density / isolation` (Layer B) ;
`A4-001 Governance quality (QoG)` et `D1-001 Governance quality (QoG)` — mêmes
WGI, deux couches (autorisé par `AGENTS.md` si le rôle est déclaré ligne par
ligne, mais le champ « Analytical role » est vide sur les deux). `A6-b01 GDP` vs
`B1-004 National income level` vs `B2-001 Income`.

**(e) Une licence à vérifier.** `E-003 Biodiversity Intactness Index (PREDICTS)`
est renseigné « Open (CC-BY) ». L'exploration Biosphere de ce workspace a établi
que le produit NHM BII v2.1.1 est diffusé en **CC-BY-NC-SA** (share-alike, accès
via une page protégée Cloudflare). L'un des deux est faux ; à trancher avant de
citer une licence dans un article.

---

## 3. Combinaisons recommandées (classées)

Rappel des contraintes non rediscutées : support commun imposé par la source la
plus grossière ; pas de variable Layer B dans le clustering ; règles de rejet
déjà en place (PC1 ≥ 65 % ⇒ gradient déguisé ; couverture < 75 % ⇒ rejet ;
max |ρ Spearman| > 0,75 ⇒ doublon).

**Un résultat de cette note à porter au dossier avant tout le reste : c'est
UTCI seul qui impose le support de 30 km.** ERA5-HEAT est à 0,25°. Toutes les
autres sources analytiques du jeu retenu sont à 1 km (Falchi, PM2.5 EEA),
90 m (WSF3D), 0,1° ≈ 11 km (E-OBS). **Si UTCI sort du jeu, un support de 10–12 km
devient défendable** — soit ~6× plus de cellules, ce qui change la puissance de
tous les diagnostics de structure. UTCI et TX > P90 mesurent tous deux la charge
thermique ; garder les deux coûte le support sans ajouter d'axe. **[V]** pour les
résolutions natives, **[S]** pour le gain analytique.

---

### P1 — « Les interfaces d'une journée ordinaire » — 3 sphères, support 11 km ★ recommandation principale

**Question** : où en Europe la vie quotidienne combine-t-elle quelles interfaces
— sans que la carte se réduise à un gradient d'urbanité ?

| # | Variable | Sphère | Mode **[S]** | Directness **[S]** | Dataset | Rés. native | Couverture EU | Licence | URL |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Fraction bâtie | A2 | spatialement visible | direct | WSF3D (DLR) | 90 m | complète (hors extrême est) | DLR open data / CC BY 4.0 | https://download.geoservice.dlr.de/WSF3D/files/ |
| 2 | PM2.5 moyenne annuelle | A1 | matériellement incorporé | **médié** (invisible) | EEA interpolated air quality | 1 km | EEA38 + UK | EEA open | https://www.eea.europa.eu/en/datahub/datahubitem-view/b51e1091-4459-4a1e-8dbc-dd7a30949b90 |
| 3 | Jours de canicule TX > P90, ≥ 3 j | A1 | matériellement incorporé | direct | E-OBS (ECA&D / C3S) | 0,1° ≈ 11 km | 25N–71,5N, 25W–45E | libre recherche (ECA&D) | https://surfobs.climate.copernicus.eu/dataaccess/access_eobs.php |
| 4 | Densité de bétail (UGB/km²) | **A3** (à trancher, voir infra) | visible + relationnel | direct | GLW 4, 2020 | 5 arcmin ≈ 10 km | globale | CC BY 4.0 | https://data.apps.fao.org/catalog/dataset/e056a913-2a28-454d-ad83-d6ef126bf0ff |
| 5 | Volume bâti par habitant (m³/hab) | **A3** | structurant matériellement | direct | WSF3D ÷ GHS-POP R2023A | 90 m ÷ 100 m | complète | CC BY 4.0 (JRC) | https://human-settlement.emergency.copernicus.eu/downloadWizard.php |

**Justification de l'indépendance.**
- (1) vs (5) : ce sont **numérateur et rapport**, pas deux mesures du même
  objet. Une cellule dense de Barcelone et une cellule pavillonnaire du Brabant
  ont un bâti élevé toutes deux, mais des m³/habitant opposés. C'est précisément
  l'axe que le trio bâti+lumière+PM2.5 écrasait. **[S]** : je m'attends à
  ρ(bâti, m³/hab) faible et **de signe instable selon le pays** — à mesurer.
- (4) vs cropland : la Bretagne, le Danemark, les Pays-Bas et la plaine du Pô
  sont extrêmes en bétail avec une part de cropland modérée ; la Beauce et la
  Moldavie sont l'inverse. **[S]** : ρ attendu positif mais < 0,5.
- (4) vs richesse : la densité de bétail est haute au Danemark (PIB élevé) comme
  en Roumanie (PIB bas) — **[S]** l'axe bétail coupe transversalement l'axe
  richesse, ce qui est la condition pour qu'il ne soit pas un filtre B déguisé.
- (2) vs (3) : PM2.5 est maximal en plaine du Pô, Pologne, Balkans (chauffage,
  industrie, inversion) ; les jours de canicule sont maximaux en Ibérie et en
  Méditerranée orientale. Géographies partiellement disjointes. **[V]** pour les
  géographies, **[S]** pour ρ < 0,5.

**Le test qui la disqualifie** — quatre observations, chacune fatale :
1. **PC1 ≥ 60 %** sur les 5 variables centrées-réduites ⇒ c'est encore un
   gradient ; la proposition tombe et il faut passer à P4.
2. **|ρ Spearman (m³/hab, PIB/hab NUTS3)| > 0,6** ⇒ le volume bâti par habitant
   fonctionne comme un filtre de richesse (Layer B) et **doit être retiré du
   clustering** : confusion de couches avérée, pas soupçonnée. C'est le test que
   j'aurais le plus peur de voir échouer.
3. **Couverture < 75 %** des cellules du masque après intersection des 5 sources.
4. **Jaccard bootstrap moyen < 0,6 pour un cluster** (bande « dissous » de
   Hennig) ⇒ l'archétype concerné n'est pas interprétable.

**Support de sortie** : **11 km** (imposé par E-OBS 0,1° et GLW4 5 arcmin, à
égalité). EPSG:3035.

**Ce qu'elle montre que les cartes existantes ne montrent pas** : toutes les
cartes d'empreinte anthropique disponibles (Human Footprint, GHS-SMOD, la carte
d'archétypes actuelle) ordonnent l'Europe sur « plus ou moins transformé ».
Aucune ne sépare *quantité de bâti* et *bâti par personne*, ni ne fait figurer
l'élevage comme interface quotidienne. Concrètement : une carte où le Randstad
et la Bretagne se retrouvent proches par (4) mais opposés par (5) est un résultat
qu'aucune carte existante ne peut produire.

**Décision ouverte à trancher par le projet, pas par moi** : la densité de bétail
est-elle A1 (propriété du paysage) ou A3 (organisation de la production
alimentaire, cf. `A3-005 Food-production involvement` et `A3-b02 Time spent with
animals`) ? La réponse détermine si P1 couvre 3 sphères ou 2. Je la traite comme
A3 ici parce que le classeur porte déjà ces deux lignes en A3, mais c'est un
argument de cohérence interne, pas une mesure.

---

### P2 — « Ce que le corps encaisse » — A1 seule, homogène par mode d'expérience, support 11 km

**Question** : où l'Anthropocène entre-t-il dans les corps, et par quelles
combinaisons de charges ?

| # | Variable | Sphère | Mode | Directness | Dataset | Rés. | Couverture | Licence | URL |
|---|---|---|---|---|---|---|---|---|---|
| 1 | PM2.5 annuel | A1 | incorporé | médié | EEA interpolated AQ | 1 km | EEA38+UK | EEA open | [datahub](https://www.eea.europa.eu/en/datahub/datahubitem-view/b51e1091-4459-4a1e-8dbc-dd7a30949b90) |
| 2 | Ozone SOMO35 | A1 | incorporé | médié | EEA interpolated AQ | 1 km | EEA38+UK | EEA open | idem |
| 3 | Jours TX > P90 (≥ 3 j) | A1 | incorporé | direct | E-OBS | 0,1° | Europe | ECA&D | [E-OBS](https://surfobs.climate.copernicus.eu/dataaccess/access_eobs.php) |
| 4 | Nuits tropicales (TN > 20 °C) | A1 | incorporé | direct | E-OBS | 0,1° | Europe | ECA&D | idem |

**Indépendance** : l'ozone troposphérique est **anti-corrélé à l'urbanité**
(titration par NO en milieu urbain) alors que PM2.5 y est corrélé — c'est un
mécanisme, pas une observation empirique locale, donc l'anti-corrélation
attendue est robuste **[V]** (chimie atmosphérique standard). Jours chauds et
nuits tropicales se séparent par la continentalité : l'Espagne intérieure a des
jours extrêmes et des nuits fraîches, le littoral méditerranéen l'inverse
**[S]**.

**Le test qui la disqualifie** : si ρ(PM2.5, jours TX>P90) > 0,6, les deux
« charges » sont un seul gradient sud/est et la carte n'est qu'un indice de
sévérité mal déguisé (⇒ basculer sur P4). Et : si les centres des clusters sont
**tous unidirectionnels** — toutes les charges bougeant dans le même sens — c'est
un gradient coupé en tranches, même échec qu'en itération 1.

**Support** : 11 km. **Ce qu'elle ajoute** : c'est la seule proposition
homogène en mode d'expérience (tout « matériellement incorporé »), donc la seule
qui se lise sans arbitrage entre « ce qu'on voit » et « ce qu'on respire ». Elle
est aussi la plus directement chaînable à Layer C (santé). Je la classe 2e et non
1re parce qu'elle **ne couvre qu'une sphère** : elle ne répond pas à la question
du projet, elle répond à une sous-question.

---

### P3 — « Urbanité non monotone » — A1 × A2, support 1 km

**Question** : à l'échelle où les gens se déplacent réellement, quels
environnements matériels se combinent — et où la fragmentation contredit-elle
l'urbanité ?

| # | Variable | Sphère | Mode | Directness | Dataset | Rés. | Couverture | Licence | URL |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Fraction bâtie | A2 | visible | direct | WSF3D | 90 m | Europe | CC BY 4.0 | [DLR](https://download.geoservice.dlr.de/WSF3D/files/) |
| 2 | Densité de mailles effective (seff) | A1/A2 | visible | direct | EEA Landscape fragmentation FGA2-S | grille 1 km | EEA39 | EEA open | https://www.eea.europa.eu/data-and-maps/data/landscape-fragmentation-effective-mesh-density |
| 3 | Luminance du ciel nocturne | A2 | visible | direct | Falchi et al., New World Atlas | modélisé ~1 km | globale | conditions du dépôt — **à vérifier** | https://b2find.eudat.eu/dataset/df8cd562-df6a-51bf-ad64-7421cf8c8623 |
| 4 | PM2.5 annuel | A1 | incorporé | médié | EEA interpolated AQ | 1 km | EEA38+UK | EEA open | [datahub](https://www.eea.europa.eu/en/datahub/datahubitem-view/b51e1091-4459-4a1e-8dbc-dd7a30949b90) |

**Indépendance — l'argument entier tient sur (2).** La fragmentation paysagère
(seff, densité de mailles pour 1 000 km²) est **non monotone en urbanité** : elle
est *basse* dans les grands massifs intacts, *basse* aussi dans un cœur urbain
continu (une seule maille bâtie), et *maximale* dans les campagnes découpées par
routes et villages diffus. Une variable non monotone en X ne peut pas être un
proxy linéaire de X : c'est ce qui la rend capable de contredire le gradient
bâti-lumière au lieu de le renforcer. **[V]** pour la définition et le calcul
(imperméabilisation Copernicus + OSM comme géométries fragmentantes),
**[S]** pour la forme non monotone en Europe — c'est exactement ce que le test
ci-dessous mesure.

**Le test qui la disqualifie** : si **|ρ Spearman (seff, fraction bâtie)| > 0,6**,
le contrepoids ne fonctionne pas — seff est alors un simple proxy d'urbanité et
la proposition redevient le trio colinéaire de l'itération 1, à support plus fin.
Deuxième test : PC1 ≥ 65 %.

**Support** : **1 km** (EPSG:3035, seff est déjà distribué sur grille 1 km).
C'est le seul jeu proposé qui autorise le support fin, parce qu'il ne contient
aucune variable climatique.

**Ce qu'elle ajoute** : à 1 km, on est à l'échelle du trajet quotidien, pas de la
région. Aucune carte européenne existante ne croise fragmentation et
imperméabilisation comme deux axes d'expérience plutôt que comme deux indicateurs
de pression.

**Réserve** : je la classe 3e parce que 3 de ses 4 variables sont des variantes
d'urbanité. Elle est la plus risquée du lot, et c'est assumé : son test unique
est franc et rapide à passer.

---

### P4 — « Le gradient assumé » — un indice continu, pas une typologie

**Question** : où l'empreinte anthropique européenne est-elle la plus forte,
mesurée honnêtement comme **une seule dimension** ?

Variables : fraction bâtie (WSF3D, 90 m), luminance du ciel (Falchi, ~1 km),
PM2.5 (EEA, 1 km), densité routière (GRIP4, 5 arcmin ≈ 9 km, CC0,
https://dataportaal.pbl.nl/GRIP4). Sphères A1–A2. Modes : visible ×3, incorporé ×1.

**Le produit n'est pas un clustering** : c'est PC1, cartographié en continu.
La justification est mesurée, pas rhétorique : sur trois de ces variables,
PC1 = 65,5 % a déjà été observé dans ce workspace. Un objet dont une seule
composante porte les deux tiers de la variance **est** un indice ; le publier
comme tel est le traitement correct, le clusteriser était l'erreur.

**Le test qui la disqualifie** : si **PC1 < 60 %**, l'indice unique n'est pas
défendable et il faut clusteriser ou éclater — c'est-à-dire revenir à P1/P3.
Second test, celui de MEDIx (§1.2) : si l'indice ne présente **aucun gradient**
vis-à-vis d'une variable Layer B tenue hors construction (PIB/hab NUTS3, part des
65+), il ne décrit pas une exposition humaine différenciée et n'a pas d'usage
dans ce projet.

**Support** : 9 km (GRIP4), ou 1 km si la densité routière est retirée.

**Ce qu'elle ajoute** : c'est le seul livrable du lot dont je peux garantir
aujourd'hui qu'il ne sera pas invalidé — il ne prétend rien de plus que ce que
les données portent. À produire **en parallèle** de P1, comme carte de contrôle :
si les archétypes de P1 ne font que redécouper ce gradient, la comparaison le
rendra visible immédiatement.

---

### Récapitulatif du classement

| Rang | Proposition | Sphères | Support | Risque principal |
|---|---|---|---|---|
| 1 | P1 — journée ordinaire | A1, A2, **A3** | 11 km | m³/hab peut être un filtre B déguisé |
| 2 | P2 — ce que le corps encaisse | A1 | 11 km | une seule sphère ; peut rester un gradient sud/est |
| 3 | P3 — urbanité non monotone | A1, A2 | **1 km** | 3 variables sur 4 sont des variantes d'urbanité |
| 4 | P4 — gradient assumé | A1, A2 | 9 km | aucun — mais ce n'est pas une typologie |

### Pourquoi aucune proposition ne couvre A4

Ce n'est pas une lacune de recherche, c'est un mécanisme, et il est testable.
Les meilleures sources A4 identifiées — WGI (`A4-001`, national, annuel),
World Values Survey, European Social Survey — sont au mieux **NUTS1/NUTS2, le
plus souvent nationales**. Projetée sur une grille de 11 km, une variable
nationale est **constante à l'intérieur de chaque pays**. Dans un k-means
standardisé, une telle variable ne contribue qu'à la variance *inter-pays* : elle
force les clusters à s'aligner sur les frontières et **absorbe** les axes
continus. Autrement dit, ajouter A4 à ce support ne produit pas une typologie
plus riche, elle produit une carte des États membres.

**Le test qui vérifie cette affirmation au lieu de la supposer** : ajouter WGI au
jeu P1, refaire le clustering, et mesurer l'information mutuelle entre étiquettes
de cluster et code pays. Si elle bondit (**[S]** : je m'attends à un doublement),
c'est démontré. Si elle ne bouge pas, j'ai tort et A4 est utilisable — ce serait
un résultat intéressant. Ce test coûte une heure.

A4 reste mobilisable en **profilage a posteriori** (comme Layer B), ce qui est
sa place naturelle : décrire les archétypes, pas les définir.

---

## 4. Features manquantes à acquérir

Une ligne par dataset candidat absent du workspace. Priorisé par gain / coût.

| # | Dataset | Fournisseur | Variable | Résolution | Couverture | Années | Licence | URL | Sphère | Ce que son ajout débloque | Coût |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **GLW 4 (2020)** | FAO | densité de bétail par espèce | 5 arcmin ≈ 10 km (aussi 1 km) | globale | 2020 (v.2015 aussi) | CC BY 4.0 | https://data.apps.fao.org/catalog/dataset/e056a913-2a28-454d-ad83-d6ef126bf0ff | A3/A1 | **le seul axe A3 gridé et pan-européen identifié** ; rend P1 tri-sphérique | facile |
| 2 | **GHS-POP R2023A** | EC JRC | population gridée | 100 m / 1 km | globale | 1975–2030 | CC BY 4.0 | https://human-settlement.emergency.copernicus.eu/downloadWizard.php | B1 + dénominateur | nécessaire au m³/hab (P1-5) et à tout profilage population | facile (déjà partiellement présent en `_shared/`) |
| 3 | **EEA interpolated AQ — ozone (SOMO35)** | AEE | O₃ | 1 km | EEA38 + UK | annuel | EEA open | https://www.eea.europa.eu/en/datahub/datahubitem-view/b51e1091-4459-4a1e-8dbc-dd7a30949b90 | A1 | 2e axe chimique **anti-corrélé à l'urbanité** ; rend P2 possible | facile (même portail que le PM2.5 déjà acquis) |
| 4 | **Landscape fragmentation seff (FGA2-S)** | AEE | densité de mailles effective | grille 1 km | EEA39 | 2009 / 2012 / 2015 | EEA open | https://www.eea.europa.eu/data-and-maps/data/landscape-fragmentation-effective-mesh-density | A1/A2 | contrepoids **non monotone** à l'urbanité ; rend P3 possible | facile |
| 5 | **GRIP4** | PBL / GLOBIO | densité routière | vecteur + raster 5 arcmin | globale | 2018 | CC0 | https://dataportaal.pbl.nl/GRIP4 | A2 | déjà catalogué (T-003) mais non acquis ; complète P4 | facile |
| 6 | **Copernicus HRL Imperviousness Density** | Copernicus / AEE | % de sol scellé | 10 m | EEA38 + UK | 2006–2024 | libre et ouvert | https://land.copernicus.eu/en/news/product-update-high-resolution-layer-imperviousness-2021 | A2 | alternative européenne à WSF3D, série temporelle exploitable | facile — **mais [S] fortement redondant avec la fraction bâtie** |
| 7 | **Eurostat NUTS3 — emploi par secteur** | Eurostat | % emploi agriculture / industrie / services | NUTS3 | UE + AELE | annuel | Eurostat open | https://ec.europa.eu/eurostat/web/regions/database | A3 | seule source A3 « structure du travail » ; **admin, donc blocs** | moyen (agrégation NUTS3 → grille ; risque de couche avec B2) |
| 8 | **END — contours de bruit (Lden)** | AEE | bruit routier/ferroviaire/aérien | contours vectoriels + version rastérisée | **agglomérations + axes majeurs seulement** | rounds 2017 / 2022 | EEA open | https://www.eea.europa.eu/en/datahub/datahubitem-view/c952f520-8d71-42c9-b74c-b7eb002f939b | A2 | interface quotidienne majeure absente du catalogue | **bloquant pour une grille** : la couverture n'est pas un pavage, l'absence de contour ≠ absence de bruit |
| 9 | **European Social Survey (round 11)** | ESS ERIC | confiance, préoccupation climatique | NUTS1/2 pour certains pays | ~30 pays | 2023 | ouvert académique | https://www.europeansocialsurvey.org/ | A4 | seule source A4 infranationale | moyen → **bloquant** : n par région trop faible pour une estimation stable **[S]** |
| 10 | **Travel time to cities** | Weiss et al. 2018, *Nature* 553:333–336 | temps de trajet vers ville ≥ 50 k | 1 km | 60S–85N | 2015 | ouvert (MAP) | https://www.nature.com/articles/nature25181 · https://malariaatlas.org/project-resources/accessibility-to-healthcare/ | **B1** | excellent — mais **c'est un filtre Layer B** (isolement), pas Layer A : à utiliser en profilage | facile (mais hors clustering, cf. §5) |

Ordre d'acquisition recommandé : **1, 3, 4, 2** (tous « facile », tous
débloquants). 5–6 sont du confort. 7–9 demandent une décision de couche avant
tout téléchargement.

---

## 5. Ce que je déconseille

1. **Bâti + lumière nocturne + PM2.5 comme typologie.** Mesuré dans ce
   workspace : PC1 = 65,5 %, silhouette 0,46. Un silhouette élevé sur un gradient
   unidimensionnel est attendu, pas rassurant. Si ces trois variables doivent
   servir, c'est en indice continu (P4).
2. **BII + fraction de cropland dans le même clustering.** ρ = −0,81, au-delà du
   seuil de doublon de 0,75 déjà retenu. Ce ne sont pas deux mesures de la
   biodiversité et de l'agriculture, c'est une mesure et son négatif à ce
   support.
3. **Densité de population + lumière nocturne.** ρ = 0,84. Et la densité de
   population est de toute façon en litige de couche (`A3-001` en Layer A vs
   `B1-005` en Layer B) : à trancher avant, pas pendant.
4. **PIB par habitant, richesse, âge, inégalité, éducation dans un clustering
   Layer A.** Ce sont des filtres B par construction. Ce n'est pas seulement une
   règle du projet : c'est ce qui détruit la seule validation forte disponible
   (§1.3) — une variable utilisée pour construire les classes ne peut plus servir
   à les tester. **En particulier `A6-b01 GDP`, actuellement rangé en Layer A
   dans le classeur, ne doit pas entrer dans un clustering A.**
5. **Temps de trajet vers la ville la plus proche (Weiss 2018) comme variable
   Layer A.** Séduisant — gridé à 1 km, pan-européen, propre. Mais
   `AGENTS.md` définit B1 comme « urbain/rural, région, pays, quartier,
   **densité, isolement** » : l'accessibilité *est* la définition de B1. L'y
   mettre en Layer A ferait entrer un filtre dans les classes. À acquérir, à
   utiliser en profilage.
6. **Ajouter UTCI *et* TX > P90 au même jeu.** Deux mesures de la charge
   thermique dont la plus grossière (0,25°) **impose seule le support de 30 km à
   toute l'analyse**. Coût élevé, gain d'axe nul. Choisir. (UTCI reste préférable
   si l'on veut le stress thermique ressenti plutôt que la température de l'air —
   mais alors le prix du support doit être payé consciemment.)
7. **Toute variable A4 (gouvernance, confiance, valeurs) dans le clustering,
   au support gridé.** Elles sont nationales ; sur une grille, elles se
   comportent comme des indicatrices pays (§3, encadré A4).
8. **Le bruit END comme couche de grille.** La couverture n'est pas un pavage :
   elle existe pour les agglomérations > 100 000 hab. et les axes majeurs. Une
   cellule sans contour n'est pas silencieuse, elle est non cartographiée.
   Utilisé tel quel, ce jeu produirait une carte de « où l'AEE a des données ».
9. **Enchaîner Human Footprint et ses composantes.** HF agrège déjà bâti,
   cropland, pâture, densité de population, lumières, voies ferrées, routes et
   voies navigables (**[V]**, description du catalogue E-004). Le combiner avec
   l'une quelconque de ces composantes, c'est compter la même mesure deux fois,
   avec en prime une corrélation qui passera sous le seuil de 0,75 sans que la
   redondance disparaisse — le seuil ne protège pas contre l'emboîtement.
10. **Choisir k au silhouette seul.** Déjà écarté ici (k = 2, centres
    unidirectionnels), et c'est la critique documentée du champ (§1.5).
11. **Un downscaling de limite planétaire comme critère de validation.** Il
    produit un jugement normatif dépendant d'un principe d'équité qu'aucune
    donnée ne peut contredire (Häyhä et al. 2016). Utilisable comme cadrage,
    jamais comme test.

---

## 6. Décisions ouvertes — à trancher par le projet, pas dans cette note

Signalées plutôt que résolues, conformément aux règles de travail et à la
section « Open Decisions » de `AGENTS.md`.

1. **Sphère de la densité de bétail** : A1 (paysage) ou A3 (organisation de la
   production alimentaire) ? Détermine si P1 couvre 3 sphères ou 2.
2. **Statut du PIB et de la densité de population** : le classeur les place en
   Layer A (`A6-b01`, `A3-001`) *et* en Layer B (`B1-004`, `B1-005`). Tant que
   ce n'est pas tranché, aucun clustering n'est auditable.
3. **Unité d'harmonisation spatiale** : raster seul, ou hybride raster + NUTS3 ?
   La question devient bloquante dès qu'on veut la moindre variable A3 socio-
   économique (ligne 7 du tableau §4).
4. **Support cible** : 30 km (statu quo, imposé par UTCI), 11 km (si UTCI sort),
   ou 1 km (si le climat sort entièrement, P3) ? Les trois sont défendables ; ils
   ne répondent pas à la même question.
5. **Baseline temporelle** : le jeu actuel mélange 2022 (UTCI, canicules),
   2024 (PM2.5), one-shot (WSF3D, Falchi), 2020 (population). GLW4 est en 2020,
   seff en 2015. Acceptable en exploratoire ; à résoudre avant Phase 6.
6. **Dénominateur de population** : population européenne totale ou population
   nationale, pour toutes les statistiques d'archétype.
7. **A5 et A6** : le brief de cette note raisonne sur A1–A4 ; le classeur porte
   aussi `A5 — Individuality` et `A6 — Economy`. Sont-elles des sphères de plein
   exercice ou un reliquat à reventiler ?

---

## Sources

**Exposome spatial**
- de Hoogh K., Hoek G., Flückiger B., Bussalleu A., Vienneau D., Jeong A. et al. (2025). *A Europe-wide characterization of the external exposome: a spatio-temporal analysis*. Environment International 200. DOI 10.1016/j.envint.2025.109542 — https://pubmed.ncbi.nlm.nih.gov/40412354/
- de Hoogh K. et al. (2024). *Socioeconomic Inequalities in the External Exposome in European Cohorts: The EXPANSE Project*. Environmental Science & Technology — https://pubs.acs.org/doi/10.1021/acs.est.4c01509
- Rodopoulou S. et al. (2024). *External exposome and all-cause mortality in European cohorts: the EXPANSE project* — https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11165119/
- Agier L. et al. (2016). *A Systematic Comparison of Linear Regression-Based Statistical Methods to Assess Exposome-Health Associations*. Environ. Health Perspect. 124(12) — https://pmc.ncbi.nlm.nih.gov/articles/PMC5132632/

**Indices d'environnement multiple**
- Richardson E., Mitchell R. et al. (2010). *Developing summary measures of health-related multiple physical environmental deprivation for epidemiological research* — https://www.research.ed.ac.uk/en/publications/developing-summary-measures-of-health-related-multiple-physical-e
- Pearce J. et al. (2011). *Environmental justice and health: a study of multiple environmental deprivation and geographical inequalities in health in New Zealand*. Soc. Sci. Med. — https://pubmed.ncbi.nlm.nih.gov/21726927/
- Ribeiro A.I. et al. (2015). *Development of a measure of multiple physical environmental deprivation. After United Kingdom and New Zealand, Portugal*. Eur. J. Public Health 25(4):610 — https://academic.oup.com/eurpub/article/25/4/610/2399153
- AEE (2019). *Unequal exposure and unequal impacts*, EEA Report 22/2018 — https://www.eea.europa.eu/en/analysis/publications/unequal-exposure-and-unequal-impacts

**Typologies spatiales**
- Stewart I.D. & Oke T.R. (2012). *Local Climate Zones for Urban Temperature Studies*. BAMS 93:1879–1900 — https://journals.ametsoc.org/view/journals/bams/93/12/bams-d-11-00019.1.xml · WUDAPT : https://www.wudapt.org/lcz/
- Singleton A.D. & Longley P.A. (2024). *Classifying and mapping residential structure through the London Output Area Classification*. Environment and Planning B — https://journals.sagepub.com/doi/full/10.1177/23998083241242913
- GHS-DUG / DEGURBA — https://human-settlement.emergency.copernicus.eu/tools/GHS-DUG_User_Guide.pdf · https://human-settlement.emergency.copernicus.eu/CFS.php
- REDCAP — https://www.researchgate.net/publication/220649615 · SKATER/GeoDa — https://geodacenter.github.io/workbook/9c_spatial3/lab9c.html · comparaison — https://arxiv.org/pdf/2209.11836

**Limites planétaires**
- Häyhä T. et al. (2016). *From Planetary Boundaries to national fair shares of the global safe operating space*. Global Environmental Change — https://www.sciencedirect.com/science/article/pii/S0959378016300826
- Ryberg M.W. et al. (2020). *Downscaling the planetary boundaries in absolute environmental sustainability assessments — a review*. J. Cleaner Prod. — https://www.sciencedirect.com/science/article/abs/pii/S0959652620333321

**Validation du clustering**
- Hennig C. (2007). *Cluster-wise assessment of cluster stability*. Comput. Stat. Data Anal. 52(1):258–271 — https://www.homepages.ucl.ac.uk/~ucakche/papers/clusta.pdf
- Tibshirani R., Walther G. & Hastie T. (2001). *Estimating the number of clusters in a data set via the gap statistic*. JRSS-B — https://www.semanticscholar.org/paper/89c8179cce5887300a8b588c86cfd3e6db0b2801
- Adolfsson A., Ackerman M. & Brownstein N. (2019). *To cluster, or not to cluster: an analysis of clusterability methods*. Pattern Recognition — https://maya-ackerman.com/wp-content/uploads/2018/09/clusterability2017.pdf

**Datasets**
GLW4 https://data.apps.fao.org/catalog/dataset/e056a913-2a28-454d-ad83-d6ef126bf0ff ·
GHSL https://human-settlement.emergency.copernicus.eu/downloadWizard.php ·
E-OBS https://surfobs.climate.copernicus.eu/dataaccess/access_eobs.php ·
EEA AQ interpolé https://www.eea.europa.eu/en/datahub/datahubitem-view/b51e1091-4459-4a1e-8dbc-dd7a30949b90 ·
EEA fragmentation https://www.eea.europa.eu/data-and-maps/data/landscape-fragmentation-effective-mesh-density ·
END bruit https://www.eea.europa.eu/en/datahub/datahubitem-view/c952f520-8d71-42c9-b74c-b7eb002f939b ·
HRL Imperviousness https://land.copernicus.eu/en/news/product-update-high-resolution-layer-imperviousness-2021 ·
GRIP4 https://dataportaal.pbl.nl/GRIP4 ·
WSF3D https://download.geoservice.dlr.de/WSF3D/files/ ·
Falchi https://b2find.eudat.eu/dataset/df8cd562-df6a-51bf-ad64-7421cf8c8623 ·
Weiss et al. 2018 https://www.nature.com/articles/nature25181 ·
Eurostat régions https://ec.europa.eu/eurostat/web/regions/database ·
ESS https://www.europeansocialsurvey.org/
