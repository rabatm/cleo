# AGENTS.md — Conventions du projet Cleo

## Versions : semver + surnom de chat

Chaque version release porte un numéro semver ET un surnom de chat, consigné dans le `CHANGELOG.md` :

```
v1.1.0 « Ronron »
v1.0.0 « Moustache »
```

- Le surnom doit avoir un rapport avec le chat (nom de chat, comportement félin, référence culturelle féline…).
- Il est choisi librement, mais doit être unique dans l'historique du changelog.
- Format dans le changelog : `## vX.Y.Z « Surnom » — AAAA-MM-JJ`.

## Commits

- Messages de commit clairs, en français ou anglais (anglais pour les fix techniques : `fix(...)`).
- Un commit = une intention cohérente (pas de mélange feature + refactor).
- Les changements visibles utilisateur doivent mentionner le surnom de la version en cours si la release est associée.

## Règle d'or

> Tout ce qui sort en version publique porte un nom de chat. Pas d'exception. Cleo veille.
