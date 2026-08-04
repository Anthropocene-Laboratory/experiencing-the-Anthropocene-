# Relier le GHD aux heatwave person-days : note de méthode

## Logique du lien

Le pipeline actuel (Phase 3) produit des **heatwave person-days** par pays — le nombre de jours de canicule × le nombre d'habitants. Cette mesure traite tous les résidents comme également exposés.

Le **Global Human Day** (Falk et al. 2023, PNAS) fournit, pour ~199 pays, le temps moyen passé par jour dans 24 sous-catégories d'activité. Certaines de ces activités exposent les gens à la chaleur ambiante (travail agricole, construction, déplacements à pied), d'autres non (bureau climatisé, sommeil avec AC).

**Le GHD intervient comme opérateur d'exposition (Layer B4)** : il transforme une mesure brute (combien de jours chauds) en mesure différentielle (combien d'heures *vécues sous la chaleur*, selon ce qu'on fait de sa journée).

### Démonstration par l'exemple

| | Espagne | Allemagne | Ratio |
|---|---|---|---|
| Heatwave days par habitant | 37 | 12 | **3.1×** |
| Heures/jour en travail agricole (GHD) | 0.15 | 0.08 | |
| **Heures d'exposition agricole** (HW days × h/jour) | 5.55 | 0.96 | **5.8×** |

L'écart presque double quand on pondère par le temps d'activité, parce que l'Espagne cumule plus de chaleur *et* plus de travail extérieur.

---

## Mapping GHD → chaleur diurne (TX) vs. nocturne (TN)

Le pipeline a déjà calculé séparément les rasters TX-only et TN-only. Le GHD permet donc **deux pondérations séparées** :

### Catégories exposées à la chaleur diurne (TX)

| Sous-catégorie GHD | Fraction outdoor estimée | Confiance | Notes |
|---|---|---|---|
| Food growth & collection | 0.70–0.95 | Moyenne-haute | Agriculture : 68% des travailleurs exposés à haute T ≥25% du temps (Eurofound EWCS 2024). En EU, 0.70–0.85 réaliste (opérations mixtes). |
| Active recreation | 0.40–0.80 | Moyenne | Très hétérogène (salle de sport = 0, course à pied = 1). Centrale ≈ 0.50. |
| Human transportation | 0.05–0.30 | Moyenne | Majorité en véhicule fermé. Marche/vélo = 100% outdoor mais minoritaire. Véhicules sans AC peuvent dépasser T ambiante. |
| Infrastructure | 0.80–0.95 | Haute | Routes et réseaux presque entièrement outdoor. 6% des travailleurs → 36% des décès par chaleur (CDC). |
| Buildings (construction) | 0.60–0.85 | Moyenne-haute | Phases de fondation/charpente outdoor ; finition intérieure sans HVAC ≈ aussi chaud que dehors. |
| Material transportation | 0.15–0.40 | Moyenne | Last-mile delivery plus exposé (0.30–0.50) ; entrepôt moins (0.05–0.15). |
| Materials (extraction) | 0.50–0.90 | Basse-moyenne | Foresterie ≈ 0.90 ; mine souterraine ≈ 0.10–0.30. Très hétérogène. |
| Waste management | 0.70–0.90 | Moyenne-haute | Collecte quasi-continue en extérieur ; tri en installation mixte. |
| Inhabited environment | 0.50–0.80 | Moyenne | Jardinage = 100% outdoor ; maintenance intérieure = 0%. Dépend de la décomposition. |

### Catégorie exposée à la chaleur nocturne (TN)

| Sous-catégorie GHD | Fraction outdoor | Mécanisme |
|---|---|---|
| Sleep & bedrest | **0.0** (mais exposition indoor critique) | Sans AC, T intérieure nocturne peut atteindre 85–100% de T extérieure, voire plus dans les étages supérieurs. Nuits chaudes = principal mécanisme de surmortalité. |

> [!IMPORTANT]
> Pour le sommeil, le bon coefficient n'est pas une « fraction outdoor » mais un **coefficient d'atténuation thermique du bâti**, modulé par la pénétration de la climatisation.

### Pénétration de la climatisation en Europe (modificateur clé pour le sommeil)

| Pays / Région | AC (% ménages) |
|---|---|
| Chypre, Malte, Grèce | 40–50%+ |
| Italie, Croatie, Espagne | 25–40% |
| France | ~15–18% |
| Allemagne | ~3–5% |
| Pays-Bas, Nordiques | ~3–8% |
| **Moyenne EU** | **~20%** |

*Sources : Odyssee-Mure, IEA, Eurofound*

### Catégories peu pertinentes (indoor / climatisable)

Allocation, Artifacts (usine), Food preparation, Food processing, Health care, Hygiene & grooming, Interactive, Meals, Passive, Physical child care, Religious practice, Schooling & research, Social.

---

## Deux options méthodologiques

### Option A : Classification binaire (plus simple, plus défendable)

Chaque catégorie GHD est codée **outdoor (= 1)** ou **indoor (= 0)**, avec un code **mixte (= 0.5)** pour les cas intermédiaires.

- **Outdoor (1.0)** : Food growth & collection, Infrastructure, Buildings, Waste management, Materials
- **Mixte (0.5)** : Active recreation, Human transport, Material transport, Inhabited environment
- **Indoor (0.0)** : Toutes les autres

Formule par pays $c$ :

$$\text{Exposure}_{TX}(c) = \text{HW\_days}_{TX}(c) \times \sum_{k \in \text{outdoor}} w_k \times h_k(c)$$

où $w_k \in \{0, 0.5, 1\}$ et $h_k(c)$ = heures/jour dans la catégorie $k$ pour le pays $c$.

Pour le sommeil :

$$\text{Exposure}_{TN}(c) = \text{HW\_days}_{TN}(c) \times h_{\text{sleep}}(c) \times (1 - \text{AC}_c)$$

> [!TIP]
> **Avantage** : Cohérent avec la méthodologie du Lancet Countdown (classification binaire outdoor/indoor par secteur). Peu d'hypothèses critiquables.
>
> **Inconvénient** : Perd la variation réelle. Traite le sport en salle et le jogging de la même façon.

### Option B : Fractions continues (plus riche, plus incertaine)

Utiliser les fractions centrales du tableau ci-dessus comme coefficients d'atténuation. Déclarer les valeurs comme hypothèses et les varier en analyse de sensibilité.

| Catégorie | Fraction centrale proposée |
|---|---|
| Food growth & collection | 0.80 |
| Active recreation | 0.50 |
| Human transportation | 0.15 |
| Infrastructure | 0.90 |
| Buildings | 0.70 |
| Material transportation | 0.25 |
| Materials | 0.65 |
| Waste management | 0.80 |
| Inhabited environment | 0.60 |
| Sleep (× (1 − AC penetration)) | Voir formule TN |

> [!WARNING]
> **Chaque chiffre est débattable.** La littérature ne fournit pas de fractions outdoor précises pour les catégories MOOGAL — ce sont des cross-walks d'expert à partir de données occupationnelles (Eurofound EWCS, ILO, EPA, CDC). La source principale d'incertitude est l'**hétérogénéité intra-catégorie** (« active recreation » va de la salle de sport au marathon).

### Recommandation

> [!IMPORTANT]
> **Option A pour l'analyse principale, Option B pour l'analyse de sensibilité.** C'est la pratique standard dans la littérature chaleur-santé (e.g., Kjellstrom utilise l'intensité métabolique par secteur comme proxy plutôt que des fractions outdoor précises). Les fractions continues sont explicitement présentées comme « coefficients d'atténuation illustratifs », pas comme des mesures empiriques.

---

## Sources clés

| Source | Ce qu'elle fournit |
|---|---|
| **Eurofound EWCS 2024** | % de travailleurs européens exposés à haute T par secteur/occupation |
| **ILO (2019) « Working on a warmer planet »** | Agriculture = 60%, construction = 19% des heures de travail perdues par chaleur |
| **Lancet Countdown (indicateur 1.1.3)** | Classification binaire outdoor/indoor par secteur ; ~26.4% des travailleurs mondiaux classés « outdoor » (collaboration OMS) |
| **NHAPS (Klepeis et al. 2001)** | 87% du temps indoor, 6% en véhicule, 7% outdoor (population US, 1992–94) |
| **EPA Exposure Factors Handbook, Ch. 16** | Distributions temps-activité par micro-environnement |
| **Kjellstrom et al. (2018)** | Fonctions dose-réponse WBGT → perte de capacité de travail |
| **Littérature atténuation thermique du bâti** | Facteurs de décrément 0.2–0.6 selon isolation |

---

## Opération concrète sur les données existantes

### Données disponibles

| Donnée | Format | Résolution | Fichier |
|---|---|---|---|
| HW days TX 2022 | Raster .nc | 0.1° grille | `heatwave_days_2022_tx_w2.nc` |
| HW days TN 2022 | Raster .nc | 0.1° grille | `heatwave_days_2022_tn_w2.nc` |
| Exposition par pays (TX) | CSV | Pays | `country_exposure_2022_tx.csv` |
| GHD all countries | CSV | Pays (ISO3) | `all_countries.csv` |
| AC penetration | À collecter | Pays | Sources IEA / Odyssee-Mure |

### Pipeline de calcul

```
1. Joindre GHD (ISO3) → exposure CSV (ISO2) via table de correspondance
2. Pour chaque pays, calculer :
   outdoor_hours(c) = Σ_k  w_k × h_k(c)    [k = catégories outdoor]
   sleep_hours(c)   = h_sleep(c)
3. Exposition diurne pondérée :
   exp_TX(c) = HW_days_TX(c) × outdoor_hours(c)
4. Exposition nocturne pondérée :
   exp_TN(c) = HW_days_TN(c) × sleep_hours(c) × (1 - AC_c)
5. Exposition totale pondérée :
   exp_total(c) = exp_TX(c) + exp_TN(c)
```

### Clé de jointure ISO2 ↔ ISO3

Le CSV d'exposition utilise des ISO2 non-standard pour certains pays (UK au lieu de GB, EL au lieu de GR). Le GHD utilise ISO3. Une table de correspondance est nécessaire.

### Couverture

31/32 pays de l'exposure CSV sont présents dans le GHD. Seul le **Liechtenstein** (LIE) manque — population négligeable (65 042).

---

## Raffinement spatial : redistribution dasymétrique (grille vs moyenne nationale)

> [!NOTE]
> Cette section est **orthogonale** au choix Option A / Option B ci-dessus (qui porte sur les coefficients `f_k`). Elle porte sur *où* on pose le budget-temps sur la grille. Les deux se combinent.

**Problème traité.** Le pipeline « Opération concrète » multiplie deux moyennes nationales : `HW_days(c) × heures_GHD(c)`. Comme l'activité agricole est spatialement corrélée au climat régional, `moyenne(a·b) ≠ moyenne(a)·moyenne(b)` : le produit des moyennes rate cette structure et collapse la grille 0.1° en 30 nombres par pays. C'est une régression de résolution **et** un biais (erreur écologique).

**Principe dasymétrique.** Le GHD fixe le **niveau national** ; un proxy spatial fixe la **distribution**. Total national conservé : `T_k(c) = H_k(c) × Pop(c)`, redistribué par un poids `w_ik` (`Σ_i w_ik = 1`) :

$$\text{exp}_{TX} = \sum_c \sum_{i \in c} \text{HW\_days}_{TX}(i) \times \sum_{k \in \text{outdoor}} f_k \times T_k(c) \times w_{ik}$$

**Le choix de `w_ik` est le seul vrai levier :**

- Catégories **liées à la population** (construction, infrastructure, transport, déchets) → `w_ik = pop_i / Pop_c`. On retombe sur la méthode nationale, et c'est correct pour elles.
- Catégories **liées au sol** (agriculture, foresterie) → `w_ik = crop_i / Σ_c crop`. C'est là, et là seulement, que l'erreur écologique mord (agriculture anti-corrélée à la population, corrélée à la chaleur régionale).

**Cadre d'interprétation — on mesure le signe, on ne le présume pas.** L'écart entre les deux méthodes est un terme de covariance, par pays :

$$\text{exp}_{\text{corrigé}} - \text{exp}_{\text{naïf}} \;\propto\; \text{Cov}_i\big(w_{\text{crop}},\, \text{HW\_days}\big)$$

> [!IMPORTANT]
> Le signe est **empirique et spécifique à chaque pays** : positif là où l'agriculture est co-localisée avec le climat chaud (probable en Espagne : cultures du sud / meseta vs population côtière plus douce), potentiellement négatif ailleurs. Le diagnostic `HW_crop(c) / HW_pop(c)` par pays fait partie des **résultats**, pas des hypothèses.

**Ce que ce raffinement ne corrige PAS (caveats distincts) :**

> [!WARNING]
> 1. **Îlot de chaleur urbain (UHI) / nocturne (TN).** Les villes sont plus chaudes la nuit, mais E-OBS à ~9 km ne résout quasiment pas l'UHI. Ce raffinement ne le touche pas ; une version UHI-aware demanderait un produit plus fin (ERA5-Land, downscaling urbain) → upgrade séparé.
> 2. **Charge radiative diurne.** Un champ nu et sec inflige une chaleur ressentie (WBGT) que TX seul ne capte pas → c'est le domaine de l'Option B (dose-réponse Kjellstrom), pas de la redistribution spatiale.

**Recette (terra, sur les rasters existants) :**

1. Couche d'usage du sol → **fraction de cropland par cellule 0.1°**, alignée sur la grille HW (source : EarthStat cropland-fraction 5 arcmin, ou CORINE / ESA-CCI en variante).
2. Par pays : `w_crop` et `w_pop`, chacun normalisé à 1.
3. Table catégorie → proxy (voir décision ouverte #6).
4. Personne-heures/cellule → × `HW_days_TX(i)` → carte + totaux pays.
5. Rapporter `Cov(w_crop, HW_days)` (ratio `HW_crop / HW_pop`) par pays comme diagnostic du signe.

---

## Décisions ouvertes

1. **Option A vs. B** pour les coefficients outdoor — à trancher avec l'équipe
2. **Source AC par pays** — Odyssee-Mure vs. IEA vs. Eurostat. Des chiffres pays par pays consolidés sont difficiles à trouver ; envisager une collecte manuelle pour les ~30 pays
3. **Poids de la chaleur en véhicule** — Le transport en véhicule sans AC peut être aussi chaud que l'extérieur. Le binaire outdoor/indoor rate ce cas. Documenter comme caveat
4. **Saisonnalité du GHD** — Les données GHD sont des moyennes annuelles, pas des moyennes estivales. Le temps passé en agriculture ou en récréation active est probablement plus élevé en été (quand les canicules se produisent). Documenter comme biais conservateur
5. **Interaction GHD × Urban/Rural (GHS-SMOD)** — Le GHD est une moyenne nationale. L'exposition réelle varie fortement entre urbain et rural. À explorer si des données GHD sub-nationales ou HETUS par type de commune existent

6. **Table catégorie → proxy spatial** (pour le raffinement dasymétrique) — défaut proposé : `crop` pour *Food growth & collection, Materials, Inhabited environment* ; `pop` pour *Infrastructure, Buildings, Waste management, Human/Material transportation, Active recreation*. À valider : « Inhabited environment » (jardinage vs maintenance intérieure) suit-il le foncier ou la population ? Et faut-il un 3ᵉ proxy « fraction forêt » pour *Materials* (foresterie) plutôt que le cropland ?

7. **Source de la couche cropland** — EarthStat 5 arcmin (≈0.1°, léger, mais millésime 2000) vs CORINE (100 m, actuel, mais couverture IS/LI/NO/CH à vérifier) vs ESA-CCI (300 m, actuel, global). Impact probablement mineur sur le *signe* de la covariance
