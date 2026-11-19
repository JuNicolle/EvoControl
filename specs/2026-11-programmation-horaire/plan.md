# Plan technique — Programmation horaire (Chrono)

Rédigé directement (pas de sous-agent `tech-lead`) : le contexte BLE/iOS déjà
établi dans ce repo est plus complet que ce qu'un agent générique
redériverait, et l'enjeu architectural est faible (un seul repo, un seul
écran). `security-auditor` n'est pas sollicité : aucune authentification,
aucun document, aucune donnée personnelle en jeu.

## Repo impacté

`EvoControl` uniquement (app iOS). Aucun autre repo du hub n'est concerné.

## Ce qu'on a trouvé en creusant le code de l'app officielle

Le format du programme Chrono n'était documenté nulle part dans nos sources
habituelles (ni `python-edilkamin`, ni `netmb/Edilkamin_BT`, qui dit
explicitement ne pas l'avoir implémenté). Je l'ai reconstitué à partir du code
Kotlin décompilé de `ChronoViewModel`/`ChronoFragment` de l'app officielle
(même source que tout le reste du protocole BLE de ce repo).

### Registres

| Registre | Rôle | Lecture | Écriture |
|---|---|---|---|
| `0x04CE` | Grille horaire, programme A | fonction 3, 42 registres (84 octets) | fonction **0x10** (write multiple registers), même taille |
| `0x04F8` | Grille horaire, programme B | idem | idem |
| `0x0522` | État on/off du Chrono + octet "programme" à préserver | fonction 3, 1 registre | fonction 6, lecture-modification-écriture (comme `0x031C` pour marche/arrêt) |
| `0x04CC` | Consigne Économie | fonction 3 | fonction 6 |
| `0x04CD` | Consigne Confort | fonction 3 | fonction 6 |

Le choix entre `0x04CE` et `0x04F8` à l'écriture dépend d'un booléen `isAuto`
dans le code source — son rôle exact (deux programmes distincts ? un mode
"auto température" vs "auto puissance" ?) n'est pas encore confirmé. À
vérifier empiriquement comme pour le reste du protocole (écrire, relire,
comparer à l'écran du poêle).

### Encodage de la grille (confirmé par lecture du code, pas encore testé sur un vrai poêle)

- 7 jours × 48 créneaux de 30 minutes = 336 créneaux.
- Chaque créneau est codé sur **2 bits** (4 valeurs possibles — vraisemblablement
  Off / Confort / Économie / une 4ᵉ valeur non identifiée).
- 4 créneaux par octet, 84 octets pour les 336 créneaux = 42 registres.
- À la lecture, l'app traite les octets par paires (un registre), prend l'octet
  bas puis l'octet haut, découpe chacun en 4 groupes de 2 bits, puis **inverse
  la liste complète** une fois tous les octets traités. L'écriture doit refaire
  l'opération inverse symétriquement.
- Dans l'UI, chaque jour est affiché en deux cadrans de 24 créneaux : AM
  (00:00–11:30) et PM (12:00–23:30), 30 minutes par créneau.
- L'ordre des 7 jours (quel index = quel jour de la semaine) n'a pas été
  confirmé — à vérifier en écrivant un seul jour connu et en comparant à
  l'écran du poêle.

### Ce qui reste incertain

- La signification exacte des 4 valeurs possibles par créneau (2 bits).
- Le rôle précis du programme `0x04CE` vs `0x04F8`.
- L'ordre des jours dans la grille de 336 créneaux.
- L'échelle des présets Économie/Confort : le code de l'app encode l'entier
  directement en hexadécimal, **sans le ×10** utilisé pour la consigne
  manuelle (`0x0525`) — à vérifier, ça pourrait être une température entière
  en degrés plutôt qu'en dixièmes.

Rien de dangereux si une valeur est mal interprétée au départ (pas de risque
matériel, juste une programmation qui ne correspond pas à ce qui a été saisi)
mais à vérifier avant de considérer la feature fiable.

## Décisions techniques

- **CRC et trame** : réutilise `EdilkaminFrame` tel quel (AES, timestamp,
  CRC16) — seule la taille de la trame change (84 octets de charge utile au
  lieu de 6), à vérifier que `EdilkaminFrame` encode/décode correctement des
  trames de cette taille (padding PKCS7 sur plusieurs blocs de 16 au lieu
  d'un seul).
- **Fonction Modbus 0x10** : `EdilkaminRegisters.Command` ne construit
  aujourd'hui que des trames à 6 octets (fonctions 3 et 6). Il faut un
  nouveau type de commande pour la fonction 0x10 (adresse, fonction, registre,
  nombre de registres, nombre d'octets, puis les octets eux-mêmes).
- **Modèle de grille** : un type `ChronoSchedule` côté Swift — 7 jours ×
  48 créneaux, valeur par créneau `enum ChronoSlot { off, economy, comfort }`
  (la 4ᵉ valeur binaire possible sera traitée comme `off` par défaut tant
  que son sens n'est pas confirmé) — avec les fonctions d'encodage/décodage
  vers/depuis les 84 octets, testées unitairement (aller-retour) avant tout
  envoi BLE réel.
- **UI** : une nouvelle vue dédiée (pas une carte de plus sur le tableau de
  bord principal, la grille est trop dense) accessible depuis l'écran
  principal, avec sélection du jour, les deux cadrans AM/PM, et les deux
  champs de préset.

## Alternatives écartées

- Implémenter la grille horaire sans l'avoir décodée (juste le on/off Chrono
  + les présets Économie/Confort) : écarté comme solution définitive, mais
  retenu comme **étape intermédiaire** livrable rapidement (voir
  `tasks.md`) pendant que la grille elle-même reste à vérifier sur le poêle.

## Risques identifiés

- **Sémantique des 2 bits par créneau non confirmée** : risque de livrer une
  grille qui s'affiche mais ne programme pas ce que l'utilisateur croit avoir
  réglé. Mitigation : lecture-avant-écriture systématique + relecture après
  écriture affichée telle quelle (comme le panneau diagnostic existant), et
  test manuel ciblé (un seul créneau à la fois) avant de faire confiance à la
  grille complète.
- **Trame 84 octets vs 6 octets habituels** : `EdilkaminFrame` n'a été
  exercé qu'avec de petites trames jusqu'ici ; blocage possible sur le
  padding PKCS7 ou la taille de notification BLE (MTU) si le poêle découpe
  la réponse en plusieurs paquets — à tester tôt.
- **Pas de retour arrière facile** : si la grille écrite est incorrecte, il
  faudra la corriger depuis l'app elle-même (ou l'écran du poêle) — pas de
  fonction "annuler" côté stove.

## Ordre de mise en production

Un seul repo, pas de contrainte de rétrocompatibilité inter-repos. Livraison
en une PR par étape (voir `tasks.md`), fusion séquentielle.
