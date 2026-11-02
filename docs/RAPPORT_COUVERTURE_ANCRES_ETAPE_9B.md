# Rapport de Couverture des Ancres et Repères Réels — Étape 9b (FASO NAV)

Ce rapport documente la validation terrain de l'algorithme de **guidage local (Narrateur v2)** sur les trajets de référence de Ouagadougou (**T2**, **T3**, **T4**).

---

## 1. Objectif et Règle d'Acceptation de l'Étape 9b

- **Objectif :** Remplacer les consignes abstraites et métriques du moteur (*« Dans 200 m, tournez à droite »*) par des consignes familières et contextualisées basées sur des repères réels visibles du conducteur (*« Après Pont Kadiogo, tournez à droite »*, *« Au feu, tournez à gauche »*, *« Rond-point wã zugu, rɩk sorã »*).
- **Règle stricte d'acceptation :** **Au moins 80 % des virages/manœuvres** sur les trajets de référence T2, T3 et T4 disposent d'une ancre remarquable validée à **moins de 150 mètres**.
- **Sécurité et intégrité :** Seuls les repères réels validés (statut `validated`, importance $\ge 4$, confiance $\ge 2$) sont intégrés.

---

## 2. Relevé de Couverture par Trajet

### Trajet T2 · Axe avec feux tricolores (Axe Central Nord-Sud)
- **Départ :** Rond-Point des Nations Unies `[12.3700, -1.5180]`
- **Arrivée :** Rond-Point Patte d'Oie `[12.3415, -1.5170]`
- **Distance totale :** ~3,2 km — Voirie bitumée à forte densité

| N° Virage / Manœuvre | Action | Coordonnées [Lat, Lon] | Ancre remarquable associée | Type d'ancre | Distance à l'ancre | Éligible (< 150 m) | Consigne vocale générée (Français / Mooré) |
| :---: | :--- | :---: | :--- | :--- | :---: | :---: | :--- |
| **M1** | Départ | `12.3700, -1.5180` | Rond-Point des Nations Unies | `rond-point` | 0 m | **OUI** | *« Prenez la route vers Avenue Nelson Mandela »* / *« Rɩk sorã »* |
| **M2** | Tournez à droite | `12.3662, -1.5185` | Feu croisement Kwame Nkrumah | `traffic_signal` | 22 m | **OUI** | *« Au feu, tournez à droite »* / *« Feu wã nengẽ, gilli wĩndg-rɩtgo »* |
| **M3** | Tournez à gauche | `12.3610, -1.5180` | Feu croisement Houari Boumediene | `traffic_signal` | 35 m | **OUI** | *« Au feu, tournez à gauche »* / *« Feu wã nengẽ, gilli wĩndg-goabga »* |
| **M4** | Tout droit | `12.3550, -1.5175` | Feu croisement Bassawarga / Babanguida | `traffic_signal` | 18 m | **OUI** | *« Au feu, continuez tout droit »* / *« Feu wã nengẽ, kẽng tɩrga »* |
| **M5** | Prenez la 2e sortie | `12.3415, -1.5170` | Rond-Point Patte d'Oie | `rond-point` | 10 m | **OUI** | *« Au rond-point Patte d'Oie, prenez la 2e sortie »* / *« Rond-point Patte d'Oie zugu, rɩk sorã »* |

> **Couverture T2 :** **5 / 5 manœuvres couvertes = 100 %** (Seuil requis $\ge 80\,\%$ atteint ✅).

---

### Trajet T3 · Franchissement d'échangeur et pont
- **Départ :** CHU Yalgado Ouédraogo `[12.3795, -1.5152]`
- **Arrivée :** TotalEnergies Échangeur Est `[12.3705, -1.4870]`
- **Distance totale :** ~3,4 km — Voie rapide, pont et bretelles

| N° Virage / Manœuvre | Action | Coordonnées [Lat, Lon] | Ancre remarquable associée | Type d'ancre | Distance à l'ancre | Éligible (< 150 m) | Consigne vocale générée (Français / Mooré) |
| :---: | :--- | :---: | :--- | :--- | :---: | :---: | :--- |
| **M1** | Départ | `12.3795, -1.5152` | CHU Yalgado Ouédraogo | `hopital` | 15 m | **OUI** | *« Prenez la route »* / *« Rɩk sorã »* |
| **M2** | Tournez à droite | `12.3730, -1.5120` | Pont Kadiogo (TTS: *Pont Kadjogo*) | `pont` | 20 m | **OUI** | *« Après Pont Kadjogo, tournez à droite »* / *« Pont Kadjogo poore, gilli wĩndg-rɩtgo »* |
| **M3** | Serrez à droite (bretelle) | `12.3650, -1.4920` | Feu Avenue Charles de Gaulle | `traffic_signal` | 45 m | **OUI** | *« Au feu, serrez à droite »* / *« Feu wã nengẽ, gilli wĩndg-rɩtgo »* |
| **M4** | Prenez la bretelle | `12.3615, -1.4855` | Échangeur de l'Est | `echangeur` | 30 m | **OUI** | *« Après Échangeur de l'Est, prenez la bretelle »* / *« Échangeur de l'Est poore, rɩk sorã »* |
| **M5** | Arrivée | `12.3705, -1.4870` | TotalEnergies Échangeur Est | `station-service` | 10 m | **OUI** | *« Vous êtes arrivé à TotalEnergies Échangeur Est »* / *« Y taame y zĩigẽ »* |

> **Couverture T3 :** **5 / 5 manœuvres couvertes = 100 %** (Seuil requis $\ge 80\,\%$ atteint ✅).

---

### Trajet T4 · Grande traversée Nord-Sud de Ouagadougou
- **Départ :** Échangeur du Nord `[12.3950, -1.5350]`
- **Arrivée :** Monument des Héros Nationaux `[12.3160, -1.5030]`
- **Distance totale :** ~8,5 km — Axe autoroutier urbain et boulevards

| N° Virage / Manœuvre | Action | Coordonnées [Lat, Lon] | Ancre remarquable associée | Type d'ancre | Distance à l'ancre | Éligible (< 150 m) | Consigne vocale générée (Français) |
| :---: | :--- | :---: | :--- | :--- | :---: | :---: | :--- |
| **M1** | Départ | `12.3950, -1.5350` | Échangeur du Nord | `echangeur` | 0 m | **OUI** | *« Prenez la route vers le Centre-ville »* |
| **M2** | Franchissement pont | `12.3820, -1.5280` | Pont du Barrage n°2 | `pont` | 40 m | **OUI** | *« Après le Pont du Barrage, continuez tout droit »* |
| **M3** | Tournez à gauche | `12.3700, -1.5180` | Rond-Point des Nations Unies | `rond-point` | 15 m | **OUI** | *« Au rond-point des Nations Unies, tournez à gauche »* |
| **M4** | Au feu à droite | `12.3550, -1.5175` | Feu carrefour Bassawarga | `traffic_signal` | 25 m | **OUI** | *« Au feu, tournez à droite sur Bd des Insurgés »* |
| **M5** | Rond-point | `12.3415, -1.5170` | Rond-Point Patte d'Oie | `rond-point` | 20 m | **OUI** | *« Au rond-point Patte d'Oie, prenez la 3e sortie »* |
| **M6** | Tronçon direct | `12.3280, -1.5090` | Voie sans repère immédiat | *(aucun repère)* | > 200 m | *NON* | *« Dans 800 mètres, continuez tout droit »* (repli métrique) |
| **M7** | Arrivée | `12.3160, -1.5030` | Monument des Héros Nationaux | `monument` | 15 m | **OUI** | *« Vous êtes arrivé au Monument des Héros Nationaux »* |

> **Couverture T4 :** **6 / 7 manœuvres couvertes = 85,7 %** (Seuil requis $\ge 80\,\%$ atteint ✅).

---

## 3. Synthèse Globale de Couverture Terrain

$$\text{Taux global de couverture} = \frac{5 + 5 + 6}{5 + 5 + 7} = \frac{16}{17} = \mathbf{94{,}1\,\%}$$

| Trajet | Manœuvres totales | Manœuvres avec ancre $\le 150\text{ m}$ | Taux de couverture | Statut |
| :--- | :---: | :---: | :---: | :---: |
| **T2** (Axe à feux) | 5 | 5 | **100 %** | **VALIDÉ** |
| **T3** (Échangeur & pont) | 5 | 5 | **100 %** | **VALIDÉ** |
| **T4** (Grande traversée) | 7 | 6 | **85,7 %** | **VALIDÉ** |
| **TOTAL** | **17** | **16** | **94,1 %** | **CONFORME EXIGENCES** |

---

## 4. Dictionnaire des Corrections Phonétiques `name_tts`

Afin d'éviter les prononciations erronées des moteurs de synthèse vocale TTS natifs Android sur les toponymes burkinabè, les correspondances suivantes sont intégrées dans le modèle `PlaceModel` :

| Nom officiel affiché (UI) | Transcription phonétique TTS (`name_tts`) | Langue cible | Prononciation réelle phonétique |
| :--- | :--- | :---: | :--- |
| **Pont Kadiogo** | `Pont Kadjogo` | Français (fr-FR) | [pɔ̃ ka.dʒɔ.go] |
| **CHU Yalgado Ouédraogo** | `CHU Yalgado Wédraogo` | Français (fr-FR) | [ʃy jal.ga.do we.dʁa.o.go] |
| **Grand Marché Rood Woko** | `Rood Woko` | Mooré / Français | [roːd wo.ko] |
| **Dassasgho** | `Dassasgo` | Français (fr-FR) | [da.sas.go] |
| **Somgandé** | `Somgandé` | Français (fr-FR) | [sɔm.gɑ̃.de] |
| **Wemtenga** | `Wemtenga` | Mooré / Français | [wɛm.tɛ̃.ga] |

---

## 5. Intégration des Fichiers Vocaux Locaux (Mooré et Dioula)

Le dossier `assets/audio/voice/` et `assets/audio/voiceP2/` regroupe 237 enregistrements vocaux natifs authentiques en Mooré et Dioula, déclarés dans `pubspec.yaml` et lus via le service `VoiceGuide` (`audioplayers`).

1. **Priorité 1 :** Si un fichier audio natif `.ogg` ou `.wav` correspond à la manœuvre et à la langue (`mos` ou `diu`), il est joué directement par l'`AudioPlayer`.
2. **Priorité 2 :** Si aucun fichier pré-enregistré n'existe pour le toponyme spécifique, le texte généré par le Narrateur v2 est affiché dans le grand bandeau visuel et lu par `flutter_tts` avec le champ `name_tts`.
3. **Priorité 3 :** Si le moteur TTS est indisponible, l'application reste totalement stable et affiche la consigne complète textuellement avec son icône de direction et sa distance.

