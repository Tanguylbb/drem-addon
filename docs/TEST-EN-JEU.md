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

- [ ] `/rempart` ouvre la fenêtre : le blason du site en haut à gauche, bouton
      fermer rouge, « Dernier Rempart » en Marcellus dans la barre de titre,
      onglets d'icônes sur le bord droit.
- [ ] Le texte est dans la police du jeu, accents compris ; aucun carré ni point
      d'interrogation à la place d'une lettre.
- [ ] La fenêtre se déplace par la barre de titre et se ferme avec Échap ou le
      bouton rouge.
- [ ] O voit l'icône **Officiers** (bouclier) ; M ne la voit pas.
- [ ] Les icônes d'onglet ont une infobulle ; l'onglet choisi est cerclé d'or.

## 2. Sorties et inscriptions (8 min)

- [ ] O : « + Nouvelle sortie » (en bas à gauche), remplir, Enregistrer. La sortie
      apparaît chez O.
- [ ] M : la sortie apparaît chez M **sans recharger** (quelques secondes).
- [ ] M : « Modifier » (sous les boutons de réponse), choisir le rôle Soins, puis
      cliquer « Présent ». Chez O, M apparaît dans les Présents avec l'icône
      soins, et la barre « Soins » monte.
- [ ] M : changer pour « Peut-être » avec un petit mot. O voit le mot.
- [ ] O : « Fermer » les inscriptions. M ne peut plus cliquer.
- [ ] O : « Modifier », changer l'heure. M voit la nouvelle heure.
- [ ] M se déconnecte. O crée une 2ᵉ sortie. M se reconnecte : la 2ᵉ sortie
      arrive dans la minute.
- [ ] Pendant un combat de boss (si possible) : rien ne casse, et une
      inscription faite juste avant part après le combat.

### 2 bis. Sorties créées par les membres (0.5, 8 min)

Il faut deux persos : O (officier) et M (membre simple).

- [ ] M : « + Nouvelle sortie » est visible. Le type **Raid est grisé** (infobulle :
      réservé aux officiers). Donjon propose 5 places et 1 / 1 / 3.
- [ ] M crée un donjon à 3 places. O le voit arriver ; la fiche dit « Organisateur :
      M ». M a « Modifier » et « Fermer » ; un 3ᵉ membre ne les a pas.
- [ ] O crée un raid : M ne peut pas le modifier (pas de boutons).
- [ ] M essaie de créer 6 sorties : à la 6ᵉ, le message dit « 5 sorties à venir ».
- [ ] Une soirée « Sans rôle » : la fiche n'a **pas** de ligne « Mon rôle » et affiche
      une barre « Places » si des places sont fixées.
- [ ] Donjon à 3 places : trois membres disent « Présent », un 4ᵉ aussi : il est
      **en liste d'attente n° 1** (toast, ligne ambre, glyphe « A » dans la liste).
      Un des trois passe en « Absent » : le 4ᵉ monte tout seul, chez tout le monde.
- [ ] Changer de rôle après avoir répondu ne fait pas perdre sa place ; passer en
      « Absent » puis revenir fait repartir au bout de la file.
- [ ] M : « Modifier » sur sa sortie, changer l'heure : O la voit changer.
- [ ] M annule sa sortie (formulaire, « Annuler la sortie ») : elle apparaît
      annulée chez tous ; « Rétablir la sortie » la remet.

## 3. Artisans (6 min)

- [ ] O (ou M) ouvre sa fenêtre de métier : le chat dit « N recettes lues et
      partagées ».
- [ ] L'autre cherche une recette dans Artisans : il trouve l'artisan, voit « en
      ligne ».
- [ ] « Demander à … » : l'artisan reçoit un message dans le chat, la commande
      est dans « Mes demandes › Pour moi ». Accepter, puis « C'est fait ».
- [ ] « À acheter » : Maj+clic sur une recette (HV, chat ou fenêtre de métier)
      remplit le champ. Ajouter. L'autre fait « +1 Je la veux ».
- [ ] Le filtre « Personne ne la sait » liste des recettes du métier que
      personne ne connaît.

## 4. Qui est là et carte du monde (4 min)

- [ ] O et M dans la même zone, hors donjon. O ouvre l'onglet **Qui est là** :
      M est dans la liste avec un point vert et « sur la carte » (≤ 10 s). Il n'y
      a aucune carte dessinée dans la fenêtre.
- [ ] O ouvre la carte du monde (touche M, ou le bouton rouge de l'onglet) : M y
      est avec son nom au survol, dans la couleur de sa classe. **C'est le
      point à vérifier en priorité** : c'est lui qui remplace l'ancienne carte.
- [ ] Un clic sur le nom de M dans la liste ouvre la carte du monde à sa zone.
- [ ] M entre dans un donjon : il disparaît de la carte et la liste dit « en
      donjon ».
- [ ] M tape `/rempart position` : il n'apparaît plus.
- [ ] Seul O partage : le texte ambre « Personne d'autre ne partage… » apparaît.
- [ ] Case « Montrer la guilde sur la carte du monde » décochée : plus de points.

## 5. Pont avec le site (4 min, O seulement)

- [ ] Écran Officiers, section « Copier-coller, en secours » (repliée, la déplier) :
      « Générer le code » : un code `DR2:…` apparaît, sélectionné. Ctrl+C,
      coller dans un bloc-notes : il est complet.
- [ ] Coller un code du site (page Pont jeu), « Vérifier » : la liste de ce qui
      va changer s'affiche. « Importer » : les sorties du site arrivent chez M.
- [ ] Le point en bas à gauche de la fenêtre est vert ; l'infobulle donne « Données
      du site : il y a … ».

## 6. Version 0.3 : ce qui ne se teste que dans le vrai jeu

**Banque de guilde et effort de guerre** (la lecture du journal est la partie la
moins sûre : le jeu peut la refuser ou la limiter sur Forever)

- [ ] Les boutons de vue sont visibles : « Objectifs / Journal de la banque »
      (Effort de guerre), « 7 jours / 30 jours / Tout » (journal), « Tous /
      Officiers » (Officiers). Sinon, le noter : sans eux on ne change pas de vue.
- [ ] **Journal de la banque** : le journal d'or lu, membre par membre, avec les
      trois chiffres du haut.
- [ ] Banque ouverte, taper `/rempart banque test` (ou le bouton « Ce que le jeu
      rend du journal » de l'écran Officiers) : « Fonctions du journal :
      présentes », un nombre de lignes pour le journal d'or et pour chaque
      onglet. Noter ce qui est dit si c'est « absentes » ou « illisible ».
- [ ] Même chose avec un membre simple, puis avec un officier : les rangs
      voient-ils tous les onglets et le journal d'or ? Noter qui voit quoi.
- [ ] O crée un objectif en or (« Nouvel objectif »), sans date de début. M dépose
      1 po dans la banque, ferme la banque. Chez M : message « banque de guilde
      lue ». Chez O : la barre de l'objectif a avancé et le dépôt est listé dans
      « Derniers dons » (l'heure n'est donnée qu'à l'heure près).
- [ ] O ouvre la banque à son tour : le total ne bouge pas (pas de doublon).
- [ ] Un retrait et une réparation ne sont **pas** comptés.
- [ ] Un objectif en objets (Maj+clic sur l'objet) : déposer l'objet dans la
      banque le fait avancer.
- [ ] Deux objectifs en or ouverts en même temps : le dépôt est « à classer »
      (pastille orange sur l'icône Effort de guerre, chez O) ; O choisit
      l'objectif avec « Classer » dans le journal de la banque.
- [ ] Écran Officiers, « Qui voit les montants » sur Officiers : M ne voit plus
      que les totaux.
- [ ] Le journal garde combien de lignes ? (noter le nombre vu après plusieurs
      dépôts : la lecture ne peut pas remonter plus loin.)

**Artisans et recettes**

- [ ] Ouvrir un métier avec des recettes non apprises : l'écran Artisans range
      les recettes par type de craft (Sacs, Robes…). Noter si les types ont les
      mêmes noms que dans la fenêtre du jeu.
- [ ] Les recettes que personne ne sait sont marquées « Personne » ; « +1 » sur
      l'une d'elles : l'autre testeur voit le compteur monter, et la recette
      apparaît dans « À acheter ».
- [ ] « Où la trouver » : saisir un texte, il arrive chez l'autre testeur.
- [ ] Un métier jamais ouvert : le bandeau rouge des Artisans le dit ; l'ouvrir
      fait disparaître le bandeau. Le chat dit une seule ligne à la connexion.

**Carte, sorties, synchro**

- [ ] Qui est là : la phrase « N en ligne · M sur la carte », et pour chaque
      membre la zone et la raison (en donjon, position coupée, pas d'add-on).
- [ ] Le point en bas à gauche est vert quand la guilde a répondu. Quand elle ne
      répond plus, il passe à l'ambre et la bande « Redemander » apparaît dans
      Sorties ; « Redemander » fait arriver une sortie manquante sans commande.
- [ ] Sorties (chez O) : la ligne « Officiers » donne des nombres plausibles, et
      « Relancer » liste ceux qui n'ont pas répondu.

**Relais automatique** (seulement quand le programme existera)

- [ ] Écran Officiers : « Pas de relais détecté » sans le mini add-on de données ;
      avec lui, l'état passe à « Relais connecté ».

## 7. Version 0.4 : le style et la navigation (la partie qui ne se voit que dans le jeu)

L'interface reprend les fenêtres du jeu avec des pièces simples (aplats, filets,
quelques images). Rien de tout ça n'a pu être vu dans le vrai client : c'est
l'essentiel de ce test.

- [ ] Le blason (écu bleu nuit, liseré et tour dorés, le même que sur le site) est
      net et déborde du coin haut gauche comme le portrait des autres fenêtres. Il
      doit garder ses proportions (plus haut que large). S'il est écrasé, flou ou
      absent, le noter.
- [ ] Le bouton fermer (rouge, croix dorée) est visible au coin haut droit.
- [ ] Les cinq icônes d'onglet sont visibles sur le bord droit, nettes, sans
      carré blanc. La pastille orange affiche un chiffre lisible.
- [ ] Les icônes des métiers (Artisans) et des types de sortie (Sorties) sont les
      bonnes ; une icône verte avec un « ? » veut dire que le jeu n'a pas trouvé
      le fichier : noter le métier ou le type.
- [ ] Les barres (rôles, objectifs) montrent un dégradé et un chiffre au milieu,
      lisible sur le fond noir comme sur la couleur.
- [ ] La fiche à droite est sur fond marine, avec le blason très pâle en bas à droite.
- [ ] Les listes défilent à la molette, la barre de défilement est visible.
- [ ] Aucun texte n'est coupé ou ne déborde de son cadre (noter l'écran et la
      ligne). Les noms longs (« Profondeurs de Brassenoire ») tiennent.
- [ ] Les cases à cocher montrent une coche dorée quand elles sont cochées.
- [ ] Les menus (filtre des recettes, choix du perso) s'ouvrent sous leur bouton
      et se ferment en cliquant ailleurs.
- [ ] Changer l'échelle de l'interface du jeu (Échelle de l'interface, 0.8 puis
      1.2) : la fenêtre reste utilisable.

## À remonter

- Le résultat de `/rempart rapport` en fin de test (capture d'écran).

- Erreurs Lua (activer `/console scriptErrors 1`) : capture du message.
- Ce qui est lent, illisible ou mal placé.
- `/rempart debug` affiche plus de détails dans le chat pendant le test.

## 8. Noms longs (0.4.1, 2 min)

Les testeurs ont vu des textes qui se superposaient quand un nom est long.

- [ ] Artisans, métier avec des types de craft aux noms longs : le nom du type se
      coupe par « … » et ne passe pas sur « N sans artisan ». Survoler l'en-tête
      donne le nom en entier.
- [ ] Recettes aux noms longs : le nom se coupe, le +1 et « N artisans » restent
      lisibles.
- [ ] Sorties : un titre long se coupe dans la liste et dans la fiche, sans
      recouvrir les boutons « Fermer » et « Modifier ».
- [ ] Sortie avec des tanks/soins/DPS demandés : la ligne « Mon rôle » est
      visible au-dessus de « Présent ». Changer de rôle après avoir répondu met
      la réponse à jour. Une soirée sans rôle demandé n'a pas cette ligne.
