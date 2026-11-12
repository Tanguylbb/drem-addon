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

## 6. Version 0.3 : ce qui ne se teste que dans le vrai jeu

**Banque de guilde et effort de guerre** (la lecture du journal est la partie la
moins sûre : le jeu peut la refuser ou la limiter sur Forever)

- [ ] Les pastilles sont visibles : « Qui sait faire quoi / Recettes recherchées /
      Commandes » (Artisans), « En cours / Terminés » (Effort de guerre),
      « Tous / Officiers ». Sinon, le noter : sans elles on ne change pas de vue.
- [ ] Onglet **Banque** : le journal d'or lu, membre par membre, avec les trois
      chiffres du haut.
- [ ] Banque ouverte, taper `/rempart banque test` (ou le bouton « Ce que le jeu
      rend » de l'onglet Banque) : « Fonctions du journal :
      présentes », un nombre de lignes pour le journal d'or et pour chaque
      onglet. Noter ce qui est dit si c'est « absentes » ou « illisible ».
- [ ] Même chose avec un membre simple, puis avec un officier : les rangs
      voient-ils tous les onglets et le journal d'or ? Noter qui voit quoi.
- [ ] O crée un objectif en or (« Nouvel objectif »), sans date de début. M dépose
      1 po dans la
      banque, ferme la banque. Chez M : message « banque de guilde lue ». Chez
      O : l'objectif a avancé et le dépôt est listé à droite (l'heure n'est
      donnée qu'à l'heure près).
- [ ] O ouvre la banque à son tour : le total ne bouge pas (pas de doublon).
- [ ] Un retrait et une réparation ne sont **pas** comptés.
- [ ] Un objectif en objets (Maj+clic sur l'objet) : déposer l'objet dans la
      banque le fait avancer.
- [ ] Deux objectifs en or ouverts en même temps : le dépôt est « à classer » ;
      O choisit l'objectif avec « Classer ».
- [ ] Réglage « Qui voit les noms et les montants » sur Officiers : M ne voit
      plus que les totaux.
- [ ] Le journal garde combien de lignes ? (noter le nombre vu après plusieurs
      dépôts : la lecture ne peut pas remonter plus loin.)

**Artisans et recettes**

- [ ] Ouvrir un métier avec des recettes non apprises : l'onglet Artisans range
      les recettes par type de craft (Sacs, Robes…). Noter si les types ont les
      mêmes noms que dans la fenêtre du jeu.
- [ ] « Personne ne l'a » liste les recettes inconnues ; « +1 » sur l'une d'elles :
      l'autre testeur voit le compteur monter, et la recette apparaît dans
      « Recettes recherchées ».
- [ ] « Où la trouver » : saisir un texte, il arrive chez l'autre testeur.
- [ ] Mes persos : un métier jamais ouvert est « À ouvrir » ; l'ouvrir le passe à
      « Lu ». Le chat dit une seule ligne à la connexion.

**Carte, sorties, synchro**

- [ ] Carte : les trois chiffres et la raison de chaque membre en ligne (sur la
      carte, autre zone, en donjon, position coupée, pas d'add-on).
- [ ] Sorties : la ligne du haut passe à « À jour : dernière réponse de … » ;
      « Redemander à la guilde » fait arriver une sortie manquante sans commande.
- [ ] Sorties : « Qui l'a vue » donne des nombres plausibles.

**Relais automatique** (seulement quand le programme existera)

- [ ] Onglet Pont : « Pas de relais détecté » sans le mini add-on de données ;
      avec lui, l'état passe à « Relais connecté ».

## À remonter

- Le résultat de `/rempart rapport` en fin de test (capture d'écran).

- Erreurs Lua (activer `/console scriptErrors 1`) : capture du message.
- Ce qui est lent, illisible ou mal placé.
- `/rempart debug` affiche plus de détails dans le chat pendant le test.
