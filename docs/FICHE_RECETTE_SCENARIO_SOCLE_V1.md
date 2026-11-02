# FICHE DE RECETTE DU SCÉNARIO — SOCLE V1 (15 Minutes)

> **Projet :** FASO NAV  
> **Date du test :** 2 Novembre 2026  
> **Condition de test :** Installation neuve, Mode Normal (Mode test désactivé), Réseau Mobile 4G activé.  
> **Téléphone 1 (Testé) :** TECNO KM4 (Android 14, 4 Go RAM)  
> **Téléphone 2 (Deuxième validation) :** ____________________ (Android ___, ___ Go RAM)  

---

## Grille d'évaluation du scénario de recette

| N° | Action à exécuter | Résultat attendu | Validé Tél 1 | Validé Tél 2 | Preuve à annexer |
| :---: | :--- | :--- | :---: | :---: | :--- |
| **1** | Installer l'app (APK release ou debug), la lancer, accepter la permission de position GPS. | Carte claire centrée sur Ouagadougou, pastille de position « Ma position » visible avec halo de précision. | [ ] | [ ] | Capture d'écran du démarrage |
| **2** | Appuyer sur l'icône de bascule thème (jour / nuit) puis revenir en mode clair. | Changement instantané du style de carte (sombre puis clair) sans disparition des repères ni saccade. | [ ] | [ ] | Capture d'écran mode sombre |
| **3** | Dans les catégories supérieures, cocher le filtre « Pharmacie », puis le décocher. | Affichage immédiat des pastilles vertes avec compteurs de grappes au dézoom ; disparition en moins d'une seconde au décochage. | [ ] | [ ] | Enregistrement vidéo écran (15 s) |
| **4** | Toucher une pharmacie sur la carte (ex. Somgandé ou Centre). | Halo vert sur le point, ouverture de la fiche détaillée avec nom, statut (ouvert/garde), quartier, boutons d'action. | [ ] | [ ] | Capture d'écran de la fiche POI |
| **5** | Appuyer sur « Itinéraire » depuis la fiche du lieu. | Calcul en moins de 2 s par Valhalla, tracé bleu continu reliant le départ exact à l'arrivée exacte, distance en km et durée estimée. | [ ] | [ ] | Capture du tracé + extrait journal |
| **6** | Appuyer sur « Démarrer la navigation vocale » et avancer (en passager moto/voiture ou à pied). | La distance restante diminue en direct sur le bandeau vert ; annonce sonore et écrite à 200 m puis à 50 m du virage (Français, Mooré ou Dioula selon choix). | [ ] | [ ] | Vidéo avec son d'une annonce virage |
| **7** | S'écarter volontairement du tracé de plus de 40 à 60 m pendant plus de 3 secondes. | Détection de sortie de route : affichage du bandeau orange « Recalcul de l'itinéraire… », nouveau tracé calculé depuis la position réelle en < 10 s. | [ ] | [ ] | Extrait du journal `[NAV]` / capture |
| **8** | Verrouiller l'écran du smartphone pendant 60 secondes en roulant/marchant. | Le service d'arrière-plan maintient le suivi GPS, la notification permanente reste active dans la barre Android. | [ ] | [ ] | Capture écran de verrouillage avec notification |
| **9** | Couper la connexion données mobiles / Wi-Fi pendant 30 secondes, puis la rétablir. | La progression sur le tracé déjà chargé continue sans plantage. Si recalcul nécessaire hors-ligne, bandeau d'alerte explicite sans écran blanc ; retour normal dès reconnexion. | [ ] | [ ] | Vidéo de coupure/rétablissement |
| **10** | Atteindre la destination réelle (à moins de 25 mètres). | L'annonce « Vous êtes arrivé » se déclenche uniquement à $\le 25\text{ m}$ du point final, après avoir parcouru le trajet. Aucun déclenchement anticipé. | [ ] | [ ] | Vidéo / journal de l'arrivée finale |
| **11** | Fermer complètement l'application (tuer la tâche) et la relancer. | L'application redémarre à l'état propre initial : aucun état fantôme de trajet en cours, carte prête pour une nouvelle recherche. | [ ] | [ ] | Capture du redémarrage |

---

## PV de Recette Finale — Décision

* [ ] **VALIDÉE SANS RÉSERVE :** Le socle technique (carte, POI, GPS, routage, guidage vocal, interface) est conforme et prêt pour le déploiement de la version `socle-v1`.
* [ ] **VALIDÉE AVEC RÉSERVES :** Réserves mineures n'empêchant pas l'usage du socle : ____________________
* [ ] **REFUSÉE :** Motif du refus : ____________________

**Signature Testeur 1 :** _________________________ **Date :** ____ / ____ / 2026  
**Signature Testeur 2 :** _________________________ **Date :** ____ / ____ / 2026  
**Signature Développeur :** _________________________ **Date :** 02 / 11 / 2026  
