# Consignes pour travailler sur ce dépôt

- Add-on WoW: Forever (client Retail Midnight, interface 16001). Lua 5.1, pas
  de bibliothèque externe : tout le code est dans `DernierRempart/`.
- Tous les textes visibles sont en français, phrases courtes, sans jargon.
- Style : celui des fenêtres du jeu (maquettes 0.5 révisées ; couleurs dans
  `UI/Theme.lua`, composants dans `UI/Widgets.lua`). Cuir brun, cadre bronze,
  noms dorés, listes noires. Rouge sombre pour l'action principale (une seule
  par écran), ardoise pour le reste ; vert = plein, ambre = il manque, rouge =
  en retard. Les fiches sont sur un panneau marine (`W.Navy`). Texte en police du
  jeu (Marcellus seulement pour le nom dans la barre de titre). Pas de glyphes
  hors Latin-1 dans les textes (→ ✓ ▸ : la police du jeu ne les a pas).
- Avant de proposer un changement d'écran : `bash tests/preview/run.sh /tmp/apercu`
  dessine chaque écran (positions, textes tronqués, chevauchements).
- Données partagées : passer par `DR.Store` (Put, Delete, Merge). Ne jamais
  écrire directement dans la sauvegarde ; la synchro diffuse toute seule les
  écritures locales.
- Nouveau champ ou jeu de données échangé avec le site : mettre à jour
  `docs/PONT.md` et `tools/php/DrPont.php` dans le même changement.
- Avant de pousser : `lua5.1 tests/run.lua`, `bash tests/interop/run.sh` et
  `luacheck DernierRempart` doivent passer.
- Pas de mise en ligne un soir de raid.

## Règles du client Forever (voir docs/RETRO-INGENIERIE.md)

- Noms : un perso s'appelle « Prénom Nom », sans royaume. Ne jamais comparer
  deux noms à la main : passer par `Util.FullName` et `Util.SameName`. Le nom
  du perso connecté est `DR.playerName`, jamais `UnitName("player")`.
- Valeurs secrètes : en combat, un nom ou un argument d'événement peut être
  secret. Tester `Util.IsSecret(v)` avant de le lire, le comparer ou le ranger.
- Ne jamais écrire dans `StaticPopupDialogs`, ni ouvrir la zone de saisie
  (`ChatFrameUtil.SendTell`), ni appeler `SetFocus` hors d'un clic du joueur.
- Avant d'ouvrir un panneau de Blizzard ou d'agir sur le groupe : demander à
  `DR.Guard` (combat, boss, manette). Un appel refusé ne lève pas d'erreur.
- Les messages entre add-ons passent tous par `DR.Comm` (débit, pause boss).
  Par chuchotement, n'accepter qu'un nom complet exact : n'importe qui peut
  chuchoter sous n'importe quel nom.
- Raidify et Guild Self Forever n'ont pas de licence : reprendre les idées,
  jamais le code ni les fichiers de données.
