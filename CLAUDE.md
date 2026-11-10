# Consignes pour travailler sur ce dépôt

- Add-on WoW: Forever (client Retail Midnight, interface 16001). Lua 5.1, pas
  de bibliothèque externe : tout le code est dans `DernierRempart/`.
- Tous les textes visibles sont en français, phrases courtes, sans jargon.
- Charte : celle des maquettes v2 du site (couleurs dans `UI/Theme.lua`). Or
  pour l'action principale (une seule par écran), Ardoise pour le reste,
  Sarcelle = plein, Ambre = il manque.
- Données partagées : passer par `DR.Store` (Put, Delete, Merge). Ne jamais
  écrire directement dans la sauvegarde ; la synchro diffuse toute seule les
  écritures locales.
- Nouveau champ ou jeu de données échangé avec le site : mettre à jour
  `docs/PONT.md` et `tools/php/DrPont.php` dans le même changement.
- Avant de pousser : `lua5.1 tests/run.lua`, `bash tests/interop/run.sh` et
  `luacheck DernierRempart` doivent passer.
- Pas de mise en ligne un soir de raid.
