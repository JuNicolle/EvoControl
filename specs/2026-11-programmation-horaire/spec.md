# Programmation horaire (Chrono)

Pas de ticket Jira — projet personnel, suivi directement ici.

## Contexte et problème résolu

EvoControl couvre aujourd'hui le pilotage manuel du poêle (allumage, consigne,
puissance, ventilateurs, Relax) mais pas la programmation automatique par plage
horaire que propose l'app officielle The Mind sous le nom « Chrono ». Sans ça,
il faut rallumer/éteindre le poêle à la main matin et soir.

## Quoi / Pourquoi

Permettre de définir, par jour de la semaine et par demi-heure, si le poêle doit
chauffer en mode **Confort** ou **Économie** (ou être coupé), puis d'activer ou
couper cette programmation automatique (le mode « Chrono ») sans quitter l'app.

Deux présets de température pilotent le Chrono :
- **Économie** : consigne basse (ex. nuit, absence)
- **Confort** : consigne normale (ex. présence)

## Critères d'acceptation

1. L'utilisateur peut activer/désactiver globalement le mode Chrono (le poêle
   suit alors la programmation plutôt qu'une consigne manuelle fixe).
2. L'utilisateur peut régler les deux températures présets, Économie et Confort.
3. L'utilisateur peut, pour chaque jour de la semaine, définir par demi-heure
   (48 créneaux/jour, 00:00–23:30) si le poêle doit être en Confort, en
   Économie, ou éteint sur ce créneau.
4. Les réglages (présets de température + grille horaire + état on/off du
   Chrono) sont lus depuis le poêle à la connexion et reflètent son état réel.
5. Un changement de grille ou de préset n'est effectif qu'après confirmation
   explicite de l'utilisateur (pas d'écriture BLE à chaque tap sur un créneau).
6. En cas de refus du poêle (erreur Modbus) ou d'échec d'écriture, l'erreur est
   visible, comme pour les autres commandes de l'app.

## Hors scope

- La minuterie simple « Easy Timer » (extinction dans X minutes) — fonction
  séparée, register déjà identifié (`0x031B`) mais non demandée ici.
- La synchronisation de l'horloge du poêle (date/heure) — nécessaire pour que
  le Chrono déclenche au bon moment, mais c'est un réglage distinct, pas
  couvert par cette feature.
- Le format exact du *contenu* du programme Chrono au-delà de
  Confort/Économie/Off (l'app officielle ne semble gérer que ces 3 états par
  créneau d'après le code examiné — voir `plan.md`).
