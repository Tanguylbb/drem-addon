# Test en jeu : 30 minutes à deux

Avant d'ouvrir l'add-on à toute la guilde, deux testeurs le font tourner dans
le vrai client de WoW: Forever. Un **officier** (O) et un **membre** (M), dans
la guilde, connectés en même temps. Notez pour chaque ligne : ✅, ❌ (avec une
capture) ou « bizarre ».

## 0. Installation (5 min)

- [ ] Copier le dossier `DernierRempart` dans le dossier `Interface/AddOns` du
      client Forever (vérifier le bon dossier : il diffère selon les guides).
- [ ] Écran de sélection, bouton AddOns : « Dernier Rempart » est listé, pas
      marqué « périmé ». Sinon, en jeu : `/dump select(4, GetBuildInfo())` et
      noter le nombre (il doit valoir 16001, comme dans le `.toc`).
- [ ] En jeu, le chat affiche « [Dernier Rempart] chargé. /rempart pour ouvrir. »
- [ ] Le blason apparaît au bord de la minicarte ; il se déplace en le glissant.
- [ ] `/reload`, puis `/rempart rapport` : la ligne « Sauvegarde » dit **relue**,
      et « Perso » donne le nom complet « Prénom Nom ». Noter les lignes
      « Erreur » et « Refus » s'il y en a.

## 1. Fenêtre et style (3 min)

- [ ] `/rempart` ouvre la fenêtre : blason, titre doré, onglets soulignés.
- [ ] Les polices Marcellus (titres) et Open Sans (texte) s'affichent, accents compris.
- [ ] La fenêtre se déplace par l'en-tête et se ferme avec Échap.
- [ ] O voit l'onglet **Pont** ; M ne le voit pas.

## 2. Sorties et inscriptions (8 min)

- [ ] O : « Nouvelle sortie », remplir, Enregistrer. La sortie apparaît chez O.
- [ ] M : la sortie apparaît chez M **sans recharger** (quelques secondes).
- [ ] M : choisir le rôle Soins, cliquer « Présent ». Chez O, M apparaît dans
      les Présents avec l'icône soins, et le compteur « soins » bouge.
- [ ] M : changer pour « Peut-être » avec un petit mot. O voit le mot.
- [ ] O : « Fermer » les inscriptions. M ne peut plus cliquer.
- [ ] O : « Modifier », changer l'heure. M voit la nouvelle heure.
- [ ] M se déconnecte. O crée une 2ᵉ sortie. M se reconnecte : la 2ᵉ sortie
      arrive dans la minute.
- [ ] Pendant un combat de boss (si possible) : rien ne casse, et une
      inscription faite juste avant part après le combat.

## 3. Artisans (6 min)

- [ ] O (ou M) ouvre sa fenêtre de métier : le chat dit « N recettes lues et
      partagées ».
- [ ] L'autre cherche une recette dans « Qui sait faire quoi » : il trouve
      l'artisan, voit « en ligne ».
- [ ] « Demander à … » : l'artisan reçoit un message dans le chat, la commande
      est dans « Commandes › Pour moi ». Accepter, puis « C'est fait ».
- [ ] « Recettes recherchées » : Maj+clic sur une recette (HV, chat ou
      fenêtre de métier) remplit le champ. Ajouter. L'autre clique « Moi aussi ».
- [ ] « Personne ne l'a » liste des recettes du métier que personne ne connaît.

## 4. Carte (4 min)

- [ ] O et M dans la même zone, hors donjon. O ouvre l'onglet Carte : la carte
      de la zone s'affiche, M y apparaît dans sa couleur de classe (≤ 10 s).
- [ ] O ouvre la carte du monde : M y est aussi, avec son nom au survol.
- [ ] M entre dans un donjon : il disparaît de la carte de O.
- [ ] M tape `/rempart position` : il n'apparaît plus.

## 5. Pont avec le site (4 min, O seulement)

- [ ] « Générer le code » : un code `DR2:…` apparaît, sélectionné. Ctrl+C,
      coller dans un bloc-notes : il est complet.
- [ ] Coller un code du site (page Pont jeu), « Vérifier » : la liste de ce qui
      va changer s'affiche. « Importer » : les sorties du site arrivent chez M.
- [ ] Le point en haut de la fenêtre passe au vert : « Données du site : il y a … ».

## À remonter

- Le résultat de `/rempart rapport` en fin de test (capture d'écran).

- Erreurs Lua (activer `/console scriptErrors 1`) : capture du message.
- Ce qui est lent, illisible ou mal placé.
- `/rempart debug` affiche plus de détails dans le chat pendant le test.
