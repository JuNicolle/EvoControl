# Tâches — Programmation horaire (Chrono)

Un seul repo (`EvoControl`), pas de contrat partagé entre repos. Adaptation du
tableau d'agents du hub : `quality-analyst` (JUnit/Vitest) et `playwright-tester`
(web) ne s'appliquent pas à un repo Swift/iOS — `ios-developer` couvre ses
propres tests (XCTest/XCUITest) dans chaque tâche, `code-reviewer` reste la
revue de PR. `security-auditor` non sollicité (pas d'auth, pas de données
personnelles).

Pas de clé Jira (projet personnel). Branches : `feature/chrono-<description>`.

## Tâche 1 — Chrono on/off + présets Économie/Confort ✅ (PR #1, revue sans point bloquant)

- **Repo** : EvoControl
- **Agent** : `ios-developer`
- **Description** : active/désactive le mode Chrono (registre `0x0522`,
  lecture-modification-écriture en préservant l'octet "programme" comme pour
  marche/arrêt), lit/écrit les deux présets de température Économie (`0x04CC`)
  et Confort (`0x04CD`). Vérifier à cette occasion si leur échelle est en
  degrés entiers ou en dixièmes (contrairement à la consigne manuelle) en
  relisant après écriture. Carte dédiée sur le tableau de bord principal,
  cohérente avec les cartes existantes (`ModeCard`, `RelaxModeCard`).
- **Livrable** : branche `feature/chrono-onoff-presets` + PR
- **Périmètre exclusif** : `Sources/BLE/EdilkaminRegisters.swift`,
  `Sources/BLE/StoveBLEManager.swift`, `Sources/BLE/StoveState.swift`,
  `Sources/Views/StoveView.swift`, nouveau
  `Sources/Views/Components/ChronoToggleCard.swift`
- **Validation** : `xcodegen generate`, `xcodebuild build ... CODE_SIGNING_ALLOWED=NO`,
  `xcodebuild test ...` (couverture ≥ 80 % sur le code ajouté)
- **Dépendances** : aucune

## Tâche 2 — Grille horaire (7 jours × 48 créneaux)

- **Repo** : EvoControl
- **Agent** : `ios-developer`
- **Description** :
  - Nouveau type de commande Modbus fonction `0x10` (write multiple registers)
    dans `EdilkaminRegisters`/`EdilkaminFrame` — la charge utile fait 84 octets
    au lieu de 6, à couvrir par un test du padding PKCS7 sur plusieurs blocs.
  - Modèle `ChronoSchedule` (7 jours × 48 créneaux, `enum ChronoSlot { off,
    economy, comfort }`) avec encodage/décodage vers les 84 octets, **testé
    unitairement en aller-retour avant tout envoi BLE réel** (c'est la partie
    entièrement testable sans matériel).
  - Lecture/écriture des registres `0x04CE`/`0x04F8` (le choix entre les deux
    reste à clarifier — voir `plan.md` — documenter la conclusion dans le code).
  - Écran dédié : sélection du jour, grille des créneaux (une grille simple de
    cases plutôt que les cadrans circulaires AM/PM de l'app officielle — ça
    remplit le même besoin pour moins d'effort), application group par group
    (par exemple sélection multiple puis "Appliquer Confort/Économie/Éteint").
  - Documenter dans la PR une procédure de vérification manuelle avec le vrai
    poêle (écrire un seul créneau connu, comparer à l'écran du poêle) pour
    confirmer l'ordre des jours et la signification des 4 valeurs possibles —
    cette vérification ne peut pas être automatisée, elle revient à
    l'utilisateur.
- **Livrable** : branche `feature/chrono-grille` + PR
- **Périmètre exclusif** : `Sources/BLE/EdilkaminFrame.swift`,
  `Sources/BLE/EdilkaminRegisters.swift`, `Sources/BLE/ChronoSchedule.swift`
  (nouveau), `Sources/BLE/StoveBLEManager.swift`,
  `Sources/Views/ChronoScheduleView.swift` (nouveau)
- **Validation** : `xcodegen generate`, `xcodebuild build ...`,
  `xcodebuild test ...` avec les tests d'aller-retour d'encodage obligatoires
- **Dépendances** : Tâche 1 mergée (réutilise `ChronoToggleCard` et la lecture
  de `0x0522`)

## Après chaque tâche

1. `code-reviewer` relit la PR (conformité à `plan.md`, qualité du diff,
   aucun secret, aucune régression sur le protocole existant).
2. Points 🔴 bloquants et 🟡 renvoyés à `ios-developer`.
3. Toi : test manuel sur le poêle réel avant de merger — en particulier pour
   la Tâche 2, où plusieurs points du format restent à confirmer.
