# Cleo

> *Le chat de ta barre de menu. Qui court..*

[![Version](https://img.shields.io/badge/version-v1.1.1%20«%20Sieste%20»-orange)](CHANGELOG.md)
[![Chat dans la barre de menu](https://img.shields.io/badge/chat-barre%20de%20menu-0a0a0a)]()
[![N'a jamais raté une sieste](https://img.shields.io/badge/qualité-siestes%20certifiées-blue)]()

---

## L'épopée

Il était une fois une barre de menu. Froide. Grise. Désespérément dépourvue de félin.

Puis **Cleo** arriva. Un chat animé qui fait du parkour dans votre barre de menu à une vitesse proportionnelle à votre CPU. Plus vous compilez, plus il sprinte. Plus vous compilez mal, plus il sprinte *vite*.

Cleo ne se contente pas de courir. Cleo *sait*. Il connaît vos quotas Claude (5 h / 7 j) et vos quotas Kimi (5 h + mensuel). Il les affiche en jolis anneaux, avec un compte à rebours de la remise à zéro, pour que vous sachiez exactement combien de temps il vous reste avant le drame.

Et quand le quota tombe à zéro… Cleo vous regarde faire. Il a tout vu venir.

## Ce que Cleo surveille

| Indicateur | Source | Rendu |
|---|---|---|
| 🏃 CPU | API Mach (`host_processor_info`) | Vitesse du chat (lissée, il ne fait pas de sprint paniqué pour un pic de 50 ms) |
| 🧠 Mémoire | `host_statistics64` + pression système | Pression (normal / warning / critical) + Go utilisés + swap |
| 🟠 Quota Claude | Endpoint officieux `/api/oauth/usage`, jeton lu dans le trousseau macOS | Anneau double : fenêtre 5 h (intérieur) et 7 j (extérieur) |
| 🌙 Quota Kimi | `api.kimi.ai/coding/v1/usages`, jeton rafraîchi depuis `~/.kimi-code/credentials/` | Anneau double : fenêtre 5 h + mensuel |

Les compteurs de quota affichent le temps restant avant remise à zéro (`3h12`, `47m`, `2j14h`) — histoire de savourer l'attente.

## Fonctionnalités

- 🐱 **Chat animé** (19 frames dessinées main, parce que Cleo mérite mieux qu'un emoji)
- 📊 **Menu détaillé** : CPU, mémoire, quotas, compte à rebours
- 🔄 **Rafraîchissement automatique** des quotas
- 🙈 **Masquage au choix** : « Afficher Claude Code » et « Afficher Kimi Code » dans le menu. Un fournisseur masqué disparaît de la barre et du panneau, et n'est plus interrogé. Cleo s'en souvient.
- 🚀 **Démarrage au login** via LaunchAgent (avec toggle dans le menu, et Cleo détecte tout seul s'il tourne déjà — il n'aime pas les sosies)
- 🪶 **Léger** : accessoire de menu (LSUIElement), zéro Dock, zéro fenêtre inutile

## Installation

Construisez avec Xcode (target `Cleo`), glissez l'app dans `/Applications`, lancez. Activez le démarrage au login depuis le menu. Cleo fait le reste.

## Exigences

- macOS récent (AppKit + SwiftUI)
- CLI Claude Code installé (pour le quota Claude — Cleo lit le jeton via `/usr/bin/security`, comme le CLI : aucune invite trousseau)
- CLI Kimi Code installé (pour le quota Kimi)

## Philosophie

> « Je ne cours pas parce que ton CPU est à 90 %. Je cours parce que *toi*, tu cours. »
> — Cleo, probablement, pendant que vous attendiez votre build.

---

*Aucun chat n'a été stressé pendant le développement. En revanche, plusieurs builds ont été observés avec mépris.*

📜 [Voir le CHANGELOG](CHANGELOG.md)
