# Le relais : un petit programme qui fait le Pont tout seul

À écrire plus tard, seulement si le copier-coller prend trop de temps aux
officiers. Ce document dit **ce que le programme doit faire** (et, surtout, ce
qu'il ne doit pas faire) pour qu'un officier puisse l'ouvrir sans crainte. Le
côté add-on est déjà en place dans la 0.3 : l'onglet Pont en montre l'état.

## Ce que fait le programme, en un passage

1. **Lit** `WTF/Account/<COMPTE>/SavedVariables/DernierRempart.lua` et en
   extrait `DernierRempartDB.outbox` : une chaîne `DR2:…` (voir `PONT.md`). Une
   simple recherche de la ligne `["outbox"] = {` et de son champ `["code"]`
   suffit, pas besoin d'un lecteur de Lua complet.
2. **Envoie** ce code au site, en HTTPS, avec la clé personnelle de l'officier.
3. **Reçoit** du site le code « site → jeu » (un code DR2 ordinaire).
4. **Écrit** `Interface/AddOns/DernierRempart_Data/Data.lua` (gabarit dans
   `tools/relais/DernierRempart_Data/`) avec ce code et ce que le site a bien
   reçu (`sent`).
5. **Affiche** ce qu'il a fait et se ferme.

Le jeu n'écrit sa sauvegarde qu'à la déconnexion ou au `/reload`, et ne relit
le mini add-on qu'à la connexion ou au `/reload` : rien n'est instantané. La
toute première fois, le dossier `DernierRempart_Data` demande un redémarrage du
jeu ; les passages suivants, un `/reload`.

## Garde-fous (pour que personne n'ait peur de l'ouvrir)

- Un seul fichier, aucun installateur, **aucun droit administrateur**, pas de
  service, pas de démarrage automatique : un double-clic, un passage, c'est fini.
- Il ne lit qu'un fichier (la sauvegarde de l'add-on) et n'écrit qu'un dossier
  (`DernierRempart_Data`). Il ne touche ni au jeu en cours, ni au compte
  Battle.net, ni à d'autres dossiers.
- Une seule adresse, écrite dans le programme : `https://dernier-rempart.eu`.
- Une clé par officier, limitée au Pont, révocable depuis le site.
- Un « mode essai » montre ce qui partirait, sans rien envoyer.
- Code public (une centaine de lignes), compilé par GitHub Actions (pas sur un
  PC), empreinte SHA-256 publiée et lien d'analyse VirusTotal avec chaque
  version. Aucune mise à jour automatique : on télécharge une nouvelle version
  en le décidant.
- Go de préférence (un seul fichier, rien à installer). Éviter les programmes
  Python empaquetés, que les antivirus signalent souvent.
- Signature de code : sans elle, Windows affiche « Windows a protégé votre PC »
  au premier lancement (Informations complémentaires, puis Exécuter quand même).
  Certains projets open source peuvent être signés gratuitement : à vérifier.

## Ce qu'il faut côté site

- Un point d'entrée qui reçoit un code DR2 du jeu (`DrPont::decode`,
  `DrPont::mergeAll`) et un qui rend le code « site → jeu » (`DrPont::encode`).
- Une page où l'officier crée et révoque sa clé.
- Ce que la 0.3 ajoute au format : `goals` et `gifts` (effort de guerre),
  voir `PONT.md`. `DrPont::goalTotal` calcule un total sans doublon.

## Sans programme du tout

Aucune installation : l'officier glisse `DernierRempart.lua` sur la page Pont
du site (le navigateur ne lit que le fichier choisi), la page en extrait le code
`DR2:` et l'envoie. Dans l'autre sens, le site propose le dossier
`DernierRempart_Data` à déposer dans `Interface/AddOns`. Un geste manuel de
plus, mais rien à installer.
