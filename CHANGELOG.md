# 📜 CHANGELOG

*Chaque version de Cleo porte le nom d'un chat légendaire. Les noms ont été validés par Cleo lui-même, qui les a tous ignorés avec la même indifférence.*

---

## v1.1.1 « Sieste » — 2026-10-27 😴

**Cleo ne réveille plus personne.**

- 🛠️ Lecture du jeton Claude Code via `/usr/bin/security`, exactement comme le CLI. Le CLI remet la « partition list » de l'item à `apple-tool:` à chaque rafraîchissement de jeton, ce qui faisait retomber l'autorisation de Cleo ; l'outil `security` reste autorisé en permanence. Plus aucune invite, même après un rafraîchissement.
- 🛠️ Fin des demandes répétées de mot de passe du trousseau. Cause : l'identité auto-signée donnait à Cleo une partition trousseau `cdhash:` qui changeait à chaque build, et securityd redemandait le mot de passe pour lire le jeton Claude Code. Cleo est désormais signée avec le certificat « Apple Development » (Team ID) : partition `teamid:` stable, une seule autorisation « Toujours autoriser » et c'est réglé. Pour de bon. Comme une sieste au soleil.
- ✨ Deux interrupteurs dans le menu, « Afficher Claude Code » et « Afficher Kimi Code » : un fournisseur masqué disparaît de la barre (le chat garde son anneau pour l'autre) et du panneau, et Cleo arrête de l'interroger. Choix mémorisé.
- 🧹 Retrait de `scripts/setup_signing.sh` (certificat auto-signé « Cleo Dev »), devenu inutile.

## v1.1.0 « Ronron » — 2026-10-16 😻

**Un menu qui ronronne.**

- ✨ Menu refait de zéro : panneau sombre, en-tête avec l'icône de Cleo et son humeur (« En pleine forme ! », « Ça s'agite un peu », « Cleo a chaud… »).
- ✨ Barres CPU (bleue) et Mémoire (violette) en dégradé, valeurs à droite.
- ✨ Claude Code et Kimi Code : anneau de quota + temps restant (« 3h 12m restantes ») + détail des fenêtres.
- ✨ Ligne « Ouvrir au démarrage » vers les Réglages Système, interrupteur « Démarrage au login », « Quitter Cleo ⌘Q ».
- 🛠️ Le popover se cale sur la taille de son contenu (le haut n'est plus coupé).
- 🧹 Retrait du bouton « Actualiser les quotas », de la pression mémoire et du swap : les quotas se rafraîchissent seuls.
- 📝 README : nouveau screenshot `Cleo3` (interface sombre, anneaux de quota) et légende mise à jour.
- 📝 README : la transmission finale s'inspire désormais de Forrest Gump, version kernel d'Alabama. Cleo a couru droit à travers le scheduler.

## v1.0.1 « Coussinet » — 2026-10-16 🩹

**Des coussinets plus stables sous les pattes.**

- 🛠️ Signature avec une identité auto-signée stable : le trousseau macOS ne perd plus les autorisations ACL à chaque rebuild. Cleo garde ses accès, comme un chat garde son canapé.
- 🛠️ LaunchAgent déployé dans le domaine `gui/<uid>` (`user/<uid>` échouait avec `EIO`). Le démarrage au login fonctionne vraiment maintenant. Testé, validé, ronronné.

## v1.0.0 « Moustache » — 2026-10-16 🎉

**Cleo a une face.**

- 🖼️ Icône d'application officielle (`AppIcon.icns`) — jusqu'ici, Cleo était un chat sans visage. Ce temps est révolu.
- Baptême du projet : RunCatPlus devient officiellement **Cleo**.
- Version 1.0 : Cleo est arrivé, il reste, et il ne partira pas.

## [v0.4.0 « Le Baptême »] — 2026-10

- ✏️ Renommage de l'app : `RunCatPlus` → `Cleo`. Le chat a enfin un nom. Les croquettes ont été distribuées pour célébrer.

## [v0.3.2 « Sosie »] — 2026-10

- 🚫 Plus de doublon quand `launchd` lance l'app alors qu'elle tourne déjà : Cleo vérifie s'il existe, et s'il existe, il s'en va poliment. Deux chats, c'est un de trop.

## [v0.3.1 « Casse-croûte »] — 2026-10

- 🛠️ Fix `launchctl bootout` (syntaxe corrigée) et `launchPath` déprécié remplacé.
- 🛠️ Le retrait du LaunchAgent est maintenant gardé par l'existence du plist — on ne démonte pas une litière vide.

## [v0.3.0 « Saut de canapé »] — 2026-10

- 🚀 **Démarrage au login** : nouveau `LaunchAgentManager` + toggle dans le menu. Cleo vous attend à votre réveil, comme un vrai chat, mais sans marcher sur votre clavier.
- 🛠️ Compilation de `LaunchAgentManager` intégrée, chemin de l'exécutable résolu proprement, API `launchctl` moderne.

## [v0.2.0 « Boule de poils »] — 2026-10

- 🧹 Nettoyage complet du cycle de vie de l'app.
- 🛠️ Fuite de ressources et courses critiques corrigées dans RunCatPlus (oui, c'était encore son nom à l'époque, on ne juge pas).

## [v0.1.0 « Chaton »] — 2026-10

- 🐣 **Naissance.** Structure de projet propre, git initialisé, premier sprint dans la barre de menu.
- Chat animé (19 frames), CPU via API Mach, mémoire via `host_statistics64`.
- Quotas Claude (5 h / 7 j) et Kimi (5 h + mensuel) avec anneaux et comptes à rebours.
- Il trottinait déjà. Il ne savait pas encore qu'il s'appellerait Cleo.

---

*Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/), versionné selon [SemVer](https://semver.org/lang/fr/). Les surnoms de chats, eux, ne suivent aucune norme ISO.*
