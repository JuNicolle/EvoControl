# EvoControl

App iOS (SwiftUI) de contrôle d'un poêle à granulés Edilkamin **Evo Cherie 11** en
Bluetooth Low Energy, pour les poêles qui ne sont pas reliés au Wi-Fi/au cloud
Edilkamin (donc hors de portée de l'app officielle « The Mind »).

## Fonctionnement

L'app parle directement au poêle en BLE, sans passer par le compte cloud :
connexion à l'appareil `EDILKAMIN_EP`, lecture et écriture de registres Modbus-RTU
encapsulés dans des trames chiffrées AES-128/CBC.

Fonctions validées sur un Evo Cherie 11 réel : allumage/extinction, lecture de la
température ambiante et de l'état, réglage de la consigne (5–35 °C, pas de 0,5 °C),
réglage de la puissance manuelle (1–5, nécessite que le poêle soit en mode manuel).

## Origine du protocole

Les UUIDs des services Bluetooth, le format des trames et la clé AES sont documentés
publiquement par le projet open source
[netmb/Edilkamin_BT](https://github.com/netmb/Edilkamin_BT), qui les a lui-même
extraits de l'app officielle à des fins d'interopérabilité (contrôler son propre
poêle sans l'app ni le Wi-Fi). Voir les commentaires de
`Sources/BLE/EdilkaminFrame.swift` et `Sources/BLE/EdilkaminRegisters.swift`.

Le code de ce dépôt est une implémentation Swift/CoreBluetooth indépendante, écrite
à partir de cette documentation publique — pas une copie du dépôt C++/Arduino
d'origine.

## Démarrer

```sh
xcodegen generate   # régénère EvoControl.xcodeproj à partir de project.yml
open EvoControl.xcodeproj
```

Nécessite de choisir une équipe de signature dans Xcode pour installer sur un
iPhone (le Bluetooth ne fonctionne pas dans le simulateur).

## Diagnostic

L'écran affiche un historique des derniers échanges Bluetooth (trame envoyée /
réponse du poêle, en hexadécimal) — utile si une commande semble sans effet.
