# FASO NAV · Jeu de Test de Référence (Étape 0)

Ce document formalise le jeu de données de référence (Ground Truth) de Ouagadougou utilisé pour valider les étapes du plan de reprise (tranche verticale, navigation, recherche, guidage local et recalage OSM).

---

## 1. 10 Lieux Repères Réels à Ouagadougou (Format GeoJSON Point)

Chaque repère est défini par son identifiant unique, son nom officiel / vernaculaire, sa catégorie normalisée, son quartier et ses coordonnées WGS 84 (`[longitude, latitude]`).

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "id": "ref-poi-01",
      "geometry": {
        "type": "Point",
        "coordinates": [-1.5428, 12.3592]
      },
      "properties": {
        "nom": "Pharmacie Yennenga",
        "categorie": "pharmacie",
        "slug": "pharmacie",
        "quartier": "Gounghin",
        "adresse": "Avenue Kadiogo, en face de la gare TSR",
        "repere_visuel": "Grande croix verte lumineuse",
        "de_garde": true
      }
    },
    {
      "type": "Feature",
      "id": "ref-poi-02",
      "geometry": {
        "type": "Point",
        "coordinates": [-1.5173, 12.3654]
      },
      "properties": {
        "nom": "Pharmacie Nouvelle",
        "categorie": "pharmacie",
        "slug": "pharmacie",
        "quartier": "Koulouba",
        "adresse": "Avenue Kwame N'Krumah",
        "repere_visuel": "Immeuble carrelé blanc avec auvent vert",
        "de_garde": false
      }
    },
    {
      "type": "Feature",
      "id": "ref-poi-03",
      "geometry": {
        "type": "Point",
        "coordinates": [-1.4885, 12.3780]
      },
      "properties": {
        "nom": "Pharmacie Wend-Kuuni",
        "categorie": "pharmacie",
        "slug": "pharmacie",
        "quartier": "Dassasgho",
        "adresse": "Avenue Charles de Gaulle",
        "repere_visuel": "Panneau vert près de l'Université Joseph Ki-Zerbo",
        "de_garde": true
      }
    },
    {
      "type": "Feature",
      "id": "ref-poi-04",
      "geometry": {
        "type": "Point",
        "coordinates": [-1.4870, 12.3705]
      },
      "properties": {
        "nom": "Station TotalEnergies Échangeur Est",
        "categorie": "station-service",
        "slug": "station-service",
        "quartier": "Dassasgho",
        "adresse": "Sortie Échangeur de l'Est, RN4",
        "repere_visuel": "Totem rouge et blanc TotalEnergies, boutique Bonjour",
        "pompes_moto": true
      }
    },
    {
      "type": "Feature",
      "id": "ref-poi-05",
      "geometry": {
        "type": "Point",
        "coordinates": [-1.5204, 12.3688]
      },
      "properties": {
        "nom": "Station Shell Koulouba",
        "categorie": "station-service",
        "slug": "station-service",
        "quartier": "Koulouba",
        "adresse": "Avenue Houari Boumediene",
        "repere_visuel": "Auvent jaune et rouge Shell",
        "pompes_moto": true
      }
    },
    {
      "type": "Feature",
      "id": "ref-poi-06",
      "geometry": {
        "type": "Point",
        "coordinates": [-1.5152, 12.3795]
      },
      "properties": {
        "nom": "CHU Yalgado Ouédraogo",
        "categorie": "hopital-sante",
        "slug": "hopital-sante",
        "quartier": "Paspanga",
        "adresse": "Boulevard de la Révolution",
        "repere_visuel": "Grand portail principal avec service des Urgences",
        "urgences_24h": true
      }
    },
    {
      "type": "Feature",
      "id": "ref-poi-07",
      "geometry": {
        "type": "Point",
        "coordinates": [-1.4721, 12.3482]
      },
      "properties": {
        "nom": "CHU de Bogodogo",
        "categorie": "hopital-sante",
        "slug": "hopital-sante",
        "quartier": "Rayongo / Bogodogo",
        "adresse": "Secteur 45, Route de Fada",
        "repere_visuel": "Nouveau complexe hospitalier vitré ocre",
        "urgences_24h": true
      }
    },
    {
      "type": "Feature",
      "id": "ref-poi-08",
      "geometry": {
        "type": "Point",
        "coordinates": [-1.5245, 12.3659]
      },
      "properties": {
        "nom": "Maquis Le Verdoyant",
        "categorie": "maquis-restaurant",
        "slug": "maquis-restaurant",
        "quartier": "Koulouba",
        "adresse": "Rue de la Chance, près de la Place de la Nation",
        "repere_visuel": "Grande terrasse arborée ombragée de manguiers",
        "specialite": "Grillades et cuisine locale"
      }
    },
    {
      "type": "Feature",
      "id": "ref-poi-09",
      "geometry": {
        "type": "Point",
        "coordinates": [-1.5085, 12.3250]
      },
      "properties": {
        "nom": "Maquis Les Étoiles de Ouaga 2000",
        "categorie": "maquis-restaurant",
        "slug": "maquis-restaurant",
        "quartier": "Ouaga 2000",
        "adresse": "Boulevard Muammar Kadhafi",
        "repere_visuel": "Hangar paillote ventilé avec enseigne lumineuse",
        "specialite": "Poulet bicyclette braisé"
      }
    },
    {
      "type": "Feature",
      "id": "ref-poi-10",
      "geometry": {
        "type": "Point",
        "coordinates": [-1.5030, 12.3160]
      },
      "properties": {
        "nom": "Monument des Héros Nationaux",
        "categorie": "monument-administratif",
        "slug": "monument",
        "quartier": "Ouaga 2000",
        "adresse": "Extrémité Sud du Boulevard Muammar Kadhafi",
        "repere_visuel": "Tour monumentale en obélisque de 55m visible à 2 km",
        "public": true
      }
    }
  ]
}
```

---

## 2. 5 Trajets de Test de Référence

Chaque trajet répond à des conditions géographiques, de voirie et de densité urbaine représentatives des défis de navigation à Ouagadougou.

| Code | Type de trajet | Départ [Lat, Lon] | Arrivée [Lat, Lon] | Distance attendue | Particularité terrain & validation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **T1** | **Court de quartier** | Marché de Gounghin<br>`[12.3560, -1.5480]` | Pharmacie Yennenga<br>`[12.3592, -1.5428]` | ~1,1 km | Voies en terre battue non goudronnées, circulation deux-roues dense, pas de signalisation verticale. Vérifier la stabilité du capteur GPS et l'absence de décrochage hors-route artificiel. |
| **T2** | **Axe avec feux tricolores** | Rond-Point des Nations Unies<br>`[12.3700, -1.5180]` | Rond-Point Patte d'Oie<br>`[12.3415, -1.5170]` | ~3,2 km | Grand boulevard bitumé central (Avenue Nelson Mandela / Bd Bassawarga), passage de 5 carrefours à feux tricolores successifs. Vérifier la détection des arrêts aux feux sans faux recalcul d'itinéraire. |
| **T3** | **Franchissement d'échangeur** | CHU Yalgado Ouédraogo<br>`[12.3795, -1.5152]` | TotalEnergies Échangeur Est<br>`[12.3705, -1.4870]` | ~3,4 km | Bretelles de raccordement et pont de l'Échangeur de l'Est (RN4) surplombant la voie ferrée. Vérifier la gestion de la superposition géométrique et le bon choix des voies de raccordement. |
| **T4** | **Traversée majeure de ville** | Échangeur du Nord<br>`[12.3950, -1.5350]` | Monument des Héros Nationaux (Ouaga 2000)<br>`[12.3160, -1.5030]` | ~8,5 km | Traversée complète Nord-Sud de Ouagadougou reliant la sortie Nord à l'extension Sud Ouaga 2000 via l'axe central. Épreuve de performance mémoire, d'autonomie GPS et de recalage continu sur 8+ km. |
| **T5** | **Trajet piéton zone dense** | Place de la Nation<br>`[12.3680, -1.5270]` | Grand Marché Rood Woko<br>`[12.3675, -1.5225]` | ~520 m | Zone piétonne et commerçante très encombrée, étals de marchands ambulants, vitesse de marche faible (~3 à 4 km/h). Vérifier l'orientation et la sensibilité du capteur compas sans saut intempestif. |

---

## 3. Critères d'Acceptation de l'Étape 0 pour ces Tests

1. **Aucune coordonnée inventée** : En cas de coupure réseau ou GPS indisponible, l'application doit refuser le calcul et afficher l'erreur explicite via `AppErrorReporter`, sans inventer l'un de ces trajets.
2. **Mode test étanche** : Ces lieux et trajets de référence sont injectés uniquement lorsque l'application est compilée avec `--dart-define=TEST_MODE=true`. En mode normal (`TEST_MODE=false`), ils ne polluent aucunement l'interface utilisateur.
3. **Traçabilité totale** : Tout calcul d'itinéraire vers l'un de ces 10 repères produit un événement dans le journal interne consultable sur l'écran Débogage (`DebugScreen`) et affiché dans les logs backend du conteneur `qvgestion-api-test`.
