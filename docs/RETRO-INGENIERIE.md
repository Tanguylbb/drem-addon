# Rétro-ingénierie de Raidify et de Guild Self Forever

Lecture du code de deux add-ons qui tournent sur WoW: Forever, pour en tirer
des mécaniques utiles à l'add-on Dernier Rempart.

- **Raidify 1.9.6** (8 novembre 2026, Raidify Team) : gestion de raid reliée au
  site raidify.app.
- **Guild Self Forever 0.25.0** (G3nkidan), abrégé GSF : règles d'une guilde
  « self found », demandes d'objets et de crafts, banques, métiers, pont vers
  un site et vers Discord.

Lecture faite le 11 novembre 2026. Aucun des deux n'a de fichier de licence :
on reprend des **idées et des mécaniques**, jamais leur code ni leurs fichiers
de données (voir la fin du document).

Repères utilisés plus bas : **R** = vu dans Raidify, **G** = vu dans GSF.

## En bref

1. Les deux add-ons confirment nos choix de base : interface **16001**,
   messages cachés entre add-ons, pause pendant les boss, lecture des recettes
   par `C_TradeSkillUI`, bouton dans le tiroir des add-ons.
2. Ils révèlent un point que nous avions faux : sur Forever un perso s'appelle
   **« Prénom Nom »**, et le jeu ne donne pas ce nom partout pareil. Notre
   version 0.2.0 aurait refusé les sorties créées par les officiers des autres.
   **Corrigé en 0.2.1**, avec d'autres garde-fous (voir la partie 4).
3. Les deux relient le jeu à leur site de la même façon : **un petit programme
   sur le PC** lit la sauvegarde de l'add-on et, pour GSF, réécrit un mini
   add-on de données. Plus de copier-coller. C'est la mécanique la plus utile
   à reprendre pour notre Pont.
4. Raidify apporte tout ce qui touche à la **soirée de raid** : former le
   groupe depuis les inscriptions, inviter, ranger les groupes, noter les
   présences, savoir qui a lu sa consigne.
5. GSF apporte tout ce qui touche à la **vie de guilde à grande échelle**
   (plusieurs centaines de membres) : qui a l'add-on et dans quelle version,
   demandes à plusieurs donneurs, catalogue de recettes embarqué, synchro par
   pages privées, annonces à l'écran.
6. Les deux ont appris à leurs dépens ce que le client Forever **refuse aux
   add-ons**. Leur liste de pièges vaut de l'or : elle est reprise en partie 1.

## 1. Ce qu'ils nous apprennent sur le client Forever

| Sujet | Ce que montre leur code | Source | Chez nous |
|-------|-------------------------|--------|-----------|
| Version | Interface `16001`, jeu 1.60.1 (builds 70124 à 70840). Le fichier `.toc` propre à Forever peut s'appeler `Nom_Camelot.toc`. | R, G | Bon |
| Contenu | Jeu de type Classic : niveau 60, métiers de Classic (pas de joaillerie), Onyxia, Cœur du Magma, Uldaman. | R, G | Bon |
| Noms des persos | « Prénom Nom », unique dans la région. `UnitName` rend « Prénom ». `UnitFullName` rend « Prénom », « Nom » (le nom à la place du royaume). La liste de guilde et l'expéditeur d'un message rendent « Prénom Nom », parfois « Prénom-Nom » ou un prénom seul. | R, G | **Corrigé 0.2.1** |
| Royaumes | Une guilde s'étale sur des royaumes liés qui ne diffèrent que par des numéros (« CAM WoW EU4 Realm 7 PvE », « CAM WoW EU5 Realm 1 PvE »). | G | **Corrigé 0.2.1** |
| Identifiant | `GetGuildRosterInfo` rend l'identifiant du perso (GUID) en 17ᵉ valeur. C'est la seule identité sans homonyme. | G | **Utilisé 0.2.1** |
| Membres hors ligne | Sans « Afficher les membres hors ligne », la liste de guilde ne donne que les connectés. GSF force l'option. | G | **Corrigé 0.2.1** |
| Messages entre add-ons | 255 octets. Par préfixe : 10 d'un coup puis 1 par seconde. Le résultat de l'envoi se lit (`Enum.SendAddonMessageResult`). Valeurs vues : 3 et 8 = trop vite, 11 = fermé un instant (combat, écran de chargement). | R, G | Bon |
| Pendant un boss | Messages entre add-ons et discussion fermés. `C_ChatInfo.InChatMessagingLockdown()` et `C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.X)` avec X = Encounter, Chat, ChallengeMode, PvPMatch, Map. | R | **Complété 0.2.1** |
| Valeurs secrètes | En combat, des noms d'unités et des arguments d'événements sont « secrets » : les comparer, les trier ou les ranger lève une erreur. Test : `issecretvalue(v)`. | R, G | **Corrigé 0.2.1** |
| Actions refusées | Un appel refusé ne lève pas d'erreur Lua. `ADDON_ACTION_BLOCKED` affiche un texte rouge. `ADDON_ACTION_FORBIDDEN` ouvre une fenêtre qui propose de **désactiver l'add-on**. | R | **Tracé 0.2.1** |
| Contamination | Écrire dans `StaticPopupDialogs`, ouvrir la zone de saisie (`ChatFrameUtil.SendTell`) ou prendre le clavier pendant que la discussion l'a : le jeu attribue ensuite à l'add-on des erreurs de Blizzard. | R | **Corrigé 0.2.1** |
| Discussion | Jamais SAY, YELL ni un canal depuis un add-on (il faut un vrai clic). Un message de guilde envoyé hors d'un clic peut être jeté sans erreur. Les chuchotements passent. | R, G | Bon (on n'écrit pas dans la discussion) |
| Groupe | Passer un groupe en raid, déplacer ou retirer quelqu'un : seulement dans un clic, jamais en combat. `C_PartyInfo.InviteUnit` est libre. | R | Sans objet pour l'instant |
| Journal de combat | Fermé aux add-ons. L'écouter lève « action réservée à l'IU de Blizzard ». | R, G | Sans objet |
| Encodage | `C_EncodingUtil` existe : JSON, CBOR, compression (zlib, deflate), Base64. Raidify s'en sert à la place de ses bibliothèques. | R | À reprendre |
| Sauvegarde | Sur la bêta, la sauvegarde était écrite mais pas relue après `/reload`. GSF garde une copie de secours dans des réglages du jeu (CVars). Raidify affiche à la connexion si la sauvegarde a été relue. | R, G | **Témoin ajouté 0.2.1**, à vérifier en jeu |
| Fichiers | Le jeu n'écrit la sauvegarde qu'à la déconnexion ou au `/reload`. Il ne réécrit que les variables déclarées dans le `.toc`. | R, G | Bon |
| Métiers | `GetProfessions` existe sur certains builds, sinon `GetSkillLineInfo`. Recettes : `C_TradeSkillUI.GetAllRecipeIDs`, `GetRecipeInfo(id).learned`, à ne lire que si `IsTradeSkillReady` et pas sur un métier lié ou de guilde. | G | Bon |
| Divers | `/who "guilde"` ne marche plus. Un add-on ne peut pas exclure un membre de la guilde. | G | Sans objet |

## 2. Raidify

### 2.1 Vue d'ensemble

Le paquet contient deux add-ons en un. Sur Classic, il charge l'ancien code
(Ace3, LibDeflate, 25 000 lignes). Sur Forever, le fichier
`Raidify_Camelot.toc` ne charge **que** le dossier `Forever/` : une réécriture
de 8 000 lignes, sans aucune bibliothèque, en trois couches.

| Couche | Rôle | Fichiers |
|--------|------|----------|
| `Data/` | Règles pures, sans appel au jeu, donc testables hors jeu | Names, Codec, Store, Reconcile, Plan, Edit, Wire, Attendance, Groups, Loot, Settings |
| `Game/` | Tout ce qui parle au jeu | Guard, Live, Actions, Comms, Invites, Arrange, Tracker, Encounter, Announce, Loot, Trade |
| `UI/` | Fenêtres | Kit, Window, quatre « phases », Paste, Hud, MyNight, FirstRun, Options, Minimap |

Chaque fichier a une seule responsabilité, annoncée en tête : « le seul
fichier qui touche aux messages », « le seul endroit où l'on compare des
noms ». C'est la même discipline que la nôtre (`DR.Store`, `DR.Comm`).

### 2.2 Le format d'import

```
RAIDIFY:v1:<type>:<base64(zlib(json))>:<somme>
```

- Types : `roster` (inscrits), `groups`, `assignments` (consignes par boss),
  `notes`, `loot`. Plusieurs morceaux se collent avec `|` dans un seul code.
- La somme de contrôle est une somme des octets pondérée par leur position,
  sur 6 chiffres hexadécimaux. Une somme fausse est signalée, pas bloquante.
- La lecture est tolérante : un morceau abîmé n'empêche pas d'importer les
  autres, et le nombre de morceaux illisibles est affiché.
- Tout repose sur `C_EncodingUtil`. La méthode de décompression n'est pas
  supposée : le code essaie chaque valeur de `Enum.CompressionMethod` et
  retient la première qui marche.

Comparé à notre `DR2:` : même idée, avec en plus la compression, une somme de
contrôle et le découpage en morceaux typés.

### 2.3 Importer, c'est fusionner

Le point fort de Raidify. Coller un code en cours de soirée ne remplace pas
tout : il met à jour.

- Même raid : fusion, avec la liste de ce qui change (arrivées, changements
  de statut ou de spé, départs). Raid différent : remplacement, annoncé.
- **Aperçu avant d'appliquer** : la fenêtre de collage montre trois colonnes
  et le bouton dit « Appliquer 3 changements ».
- **Un niveau d'annulation** : la soirée d'avant le dernier import est gardée.
- Les joueurs ajoutés à la main en jeu survivent à tous les imports.
- Une consigne modifiée en jeu n'est **jamais** écrasée en silence : sans
  choix de l'officier, la version du jeu reste et le conflit est affiché
  (« garder la mienne » ou « prendre celle du site »).
- Le pied de la fenêtre rappelle toujours ce que le dernier import a changé.

### 2.4 Les noms

Un module entier (`Names`) existe pour ne jamais confondre deux joueurs.

- Clé d'un nom : minuscules, tiret remplacé par un espace, espaces simples.
- Un nom du site sans nom de famille ne correspond à un joueur que s'il est
  **le seul** à porter ce prénom. Sinon l'add-on dit « ambigu » et demande à
  l'officier de choisir. Le choix est gardé sur la fiche.
- Pour les invitations par chuchotement, une faute de frappe d'une lettre est
  tolérée sur les noms de 5 lettres et plus, si un seul nom s'en approche.
- Un écran de diagnostic liste « nom du site → nom en jeu (comment il a été
  trouvé) ».

### 2.5 Du jeu vers le site

- Les présences et le butin sont écrits dans la sauvegarde
  (`RaidifyForeverDB.char[<perso>]`).
- Un programme de bureau, le **Raidify Companion**, lit ce fichier et envoie
  les données au site. Le calcul des présences existe en double, dans l'add-on
  et dans le Companion, et les deux doivent rester identiques.
- Secours : un bouton fabrique un code à copier dans le site.

### 2.6 Entre les joueurs : « le plan »

Les officiers importent. Les raideurs, eux, ne collent jamais rien : ils
reçoivent le plan par des messages cachés.

- Préfixe `RaidifyF`, canal RAID ou PARTY. Le plan est empaqueté une fois
  (CBOR, compression, Base64), coupé en morceaux de 230 octets, réassemblé et
  appliqué seulement quand il est complet.
- Quatre messages : `P` (morceau du plan), `H<révision>` (« j'ai Raidify et
  ce plan »), `A<révision>:<boss>` (« j'ai lu ma consigne »), `Q` (« envoie-moi
  le plan »).
- Seuls le chef de raid et ses assistants peuvent envoyer un plan. Le
  récepteur vérifie le rôle de l'expéditeur dans le groupe.
- Chaque changement augmente une **révision** datée par l'heure du serveur. Un
  plan plus vieux que celui qu'on a est refusé.
- Envoi automatique 2 secondes après le dernier changement. Un envoi plus
  récent remplace celui qui attend encore.
- Quand un joueur dit bonjour avec une révision plus vieille, un officier
  renvoie le plan tout seul.
- **Bandeau de remise** pour l'officier : sur ce boss, combien ont l'add-on,
  combien ont lu leur consigne, et qui ne l'a pas.
- Débit : 8 messages d'avance, 1 toutes les 1,05 secondes. Pause de 3 secondes
  quand le jeu ferme les messages, reprise à la fin du boss.
- Le butin et les notes d'officiers ne sont jamais dans le plan, puisque tout
  le raid le reçoit.

### 2.7 Deux officiers modifient en même temps

À la première modification d'un boss, la version du site est mise de côté.
Quand un plan plus récent arrive d'un autre officier : les boss que lui n'a
pas touchés gardent mes changements, et le plan repart vers le raid. Là où
les deux ont modifié le même boss, le plus récent gagne et je suis prévenu.

### 2.8 Former le raid

- **État de chaque inscrit**, calculé en croisant le site, le groupe et la
  liste de guilde : dans le groupe, en ligne (invitable), hors ligne, inconnu
  (hors guilde), ambigu. S'y ajoutent les « extras » : présents non inscrits.
- **Inviter** : jamais plus que les places restantes, une invitation toutes
  les 0,5 seconde, pas de second lot pendant que le premier part.
- **Continuer d'inviter** : une passe toutes les 60 secondes au moins, 15
  passes au plus. S'arrête si le raid est plein, si tous les attendus sont là,
  si on perd l'assistance. Ceux qui ont refusé ne sont plus relancés (lu dans
  le message système du jeu).
- **Inviter sur chuchotement** : mot clé réglable (« inv »), reconnu en début
  de message et en mot entier, 10 secondes de délai par joueur, réservé aux
  inscrits si on veut, avec réponse automatique.
- **Ranger les groupes** : le plan donne le groupe voulu de chacun. L'add-on
  calcule la liste des déplacements et des échanges, en fait un toutes les
  0,15 seconde, et attend la fin du combat.

### 2.9 Les présences

- Toutes les 30 secondes et à chaque changement du groupe : première et
  dernière fois vu, pour chaque joueur. Un déconnecté n'est plus « vu ».
- La soirée commence quand le raid est vu pour la première fois, pas au
  moment du collage. Personne n'est noté en retard à tort.
- Classement : présent, en retard (5 minutes de tolérance), parti tôt
  (5 minutes), remplaçant marqué par le chef, excusé, absent, non inscrit.
- Fin automatique sur le dernier boss de la dernière instance prévue, lu dans
  le journal des rencontres du jeu. Dans le doute, la soirée reste ouverte.
- Les 5 dernières soirées sont gardées tant qu'elles ne sont pas envoyées.

### 2.10 Le butin, en deux mots

Conseil de butin : listes de souhaits importées du site, candidats triés,
jets de dés lus dans la discussion, attribution annoncée, suivi du délai
d'échange de 2 heures, aide dans la fenêtre d'échange. L'échange n'est noté
qu'à la réception du message « échange terminé », car `TRADE_CLOSED` arrive
avant. Hors de notre besoin actuel.

### 2.11 Les garde-fous

Un fichier, `Guard`, répond à « ai-je le droit de faire ça maintenant ? ».

- Toute ligne de discussion passe par lui, après avoir vérifié que la
  discussion est ouverte aux add-ons.
- Chaque refus du jeu est enregistré avec sa pile d'appels, compté, et
  expliqué une seule fois au joueur. `/rf report` copie la version du jeu, les
  50 dernières erreurs et les refus.
- Fenêtres de confirmation faites maison, jamais celles de Blizzard.
- Chuchoter : l'add-on affiche un nom à cliquer au lieu d'ouvrir la zone de
  saisie.
- Prendre le clavier : attendre que la discussion l'ait lâché.
- À la manette, les panneaux de Blizzard ne sont pas ouverts par l'add-on.

### 2.12 L'interface

- La fenêtre suit la soirée en quatre **phases** : Ce soir, Formation, En
  raid, Après. Chaque phase affiche un compteur de ce qui demande une action.
- **Ma soirée**, pour le raideur : son statut, son groupe, sa consigne sur
  chaque boss, marquée « lue » ou « nouvelle ».
- Un petit **panneau de combat** qui n'apparaît que s'il y a un plan : le boss
  en cours, ma consigne, « Compris ».
- **Premier écran** quand rien n'est chargé : trois étapes et un exemple animé.
- Les réglages sont décrits dans une seule liste, d'où est fabriqué le panneau
  d'options de Blizzard.
- Une version de développement s'installe à côté de la vraie, avec des
  données de démonstration et des tests lancés en jeu.

## 3. Guild Self Forever

### 3.1 Vue d'ensemble

54 fichiers de code, environ 47 000 lignes, plus 190 000 lignes de données. Tout est
accroché à une seule table. Les domaines :

| Domaine | Fichiers | Intérêt pour nous |
|---------|----------|-------------------|
| Réseau, versions, présence | VersionCheck, Presence | Fort |
| Identités et guilde | Guild, Identity, Core, Persistence | Fort |
| Métiers et recettes | Professions, CraftRequests, Data/ | Fort |
| Demandes | Requests, RequestSync, RequestLedgerSync, RequestsUI, Mail | Fort |
| Pont vers le site | BridgeExport, CollectorProof, DiscordLink, BridgeReminder | Fort |
| Réglages partagés, rôles | SharedLists, Roles | Moyen |
| Banques, effort de guerre | Banks, FederationBanks, WarEffort, GuildBankSort | Moyen |
| Annonces | Deaths, Level60, Tombola | Moyen |
| Plusieurs guildes | Federation, FederationWhisperRelay, Whitelist, AlliedMail | Faible |
| Anti-triche | Audit, Adventure, Trade, Mail, AuctionHouse, CraftedOutsider, ServerStats, BanRelay | Aucun |
| Interface, outils | GuildUI, UIKit, WindowScale, Options, Onboarding, Diagnostics, Perf | Moyen |

### 3.2 Le réseau

- Un seul préfixe. Des lignes de texte : `COMMANDE|champ|champ`.
- **Budget en octets** : 4 000 octets d'avance, 2 000 par seconde, 75 ms entre
  deux envois. Quand le jeu répond « trop vite », le message reste en tête et
  repart 1 seconde plus tard, 8 fois au plus.
- **Quatre files** : alertes (petits messages), réponses aux guildes alliées,
  discussion commune (un quart du budget, 30 secondes de vie), gros
  transferts. Les alertes ne passent jamais derrière un gros transfert.
- Un transfert coupé en morceaux forme un **groupe** : si un morceau est
  perdu, tous les autres sont retirés de la file.
- Un chuchotement vers un membre hors ligne n'est pas envoyé. Cela évite les
  messages « joueur introuvable ».
- Réception : 3 transferts ouverts au plus par expéditeur, oubliés après un
  délai sans nouvelles.
- **Battement** toutes les 57 à 63 secondes : `HELLO|version|protocole`. Le
  décalage vient du nom du joueur, pour que toute la guilde n'envoie pas en
  même temps.
- Réponses : une par demandeur et par type toutes les 15 à 30 secondes. Le
  délai avant de répondre vient d'un calcul sur le nom et le jeton, les
  officiers répondent d'abord. Seule la réservation d'un officier fait taire
  les autres, sinon un membre pourrait bloquer toute la synchro.
- Leçon de terrain notée dans le code : à 300 membres, laisser chacun
  répondre à chaque demande faisait 150 demandes par minute et noyait les
  files. Depuis, un seul répond, et seulement si son empreinte diffère.
- `/gsf netstatus` : taille des files, messages jetés, erreurs, par commande.

### 3.3 Les identités sur Forever

C'est la partie la plus travaillée, après plusieurs corrections de sécurité.

- Clé d'un membre : le nom de la liste de guilde, sans royaume, en minuscules.
- Un nom reçu est retrouvé dans cet ordre : nom exact, forme « Prénom-Nom »,
  prénom seul **si un seul membre le porte**. Jamais de devinette entre deux
  homonymes.
- L'identifiant du perso (GUID) lu dans la liste de guilde tranche sans
  ambiguïté quand il est disponible.
- **Le canal GUILDE prouve l'appartenance** : seuls les membres le reçoivent.
  **Un chuchotement ne prouve rien** : n'importe qui peut en envoyer un, sous
  n'importe quel nom. Par chuchotement, seul un nom complet exact est accepté.
- Un nom abrégé n'est jamais gardé quand le nom complet est connu.

### 3.4 Une base par guilde

Les données sont rangées par « royaume + guilde », sans les numéros de
royaume. Un compte peut avoir des persos dans plusieurs guildes sans mélange.
Les anciennes sauvegardes sont migrées une fois, puis vidées.

### 3.5 La sauvegarde

- Copie de secours après `/reload` dans des réglages du jeu : deux bancs de
  morceaux et un en-tête avec longueur et empreinte. Le nouveau cache est
  écrit dans le banc libre, puis l'en-tête bascule : une écriture coupée
  laisse l'ancien intact.
- À la déconnexion, l'add-on écrit sa version et l'heure. Le pont sait ainsi
  quelle version a produit le fichier.
- Rien n'est écrit avant la connexion complète : le nom de la guilde arrive
  parfois une seconde après.

### 3.6 Les versions

- Chaque battement porte la version. Chaque client garde celle des autres.
- **Version exigée** = la plus haute annoncée par un officier depuis 14 jours.
  Un officier qui revient en arrière la fait redescendre.
- État de chaque membre, visible des officiers : à jour, dépassé,
  incompatible, add-on jamais vu, add-on perdu de vue.
- Rappel de mise à jour une fois par version, 8 secondes après la connexion.
- Les anciens clients ignorent les commandes qu'ils ne connaissent pas : on
  ajoute des commandes, on ne change jamais le format d'une commande existante.

### 3.7 Les métiers

- Chaque joueur publie ses métiers et ses niveaux. Une fiche relayée par un
  autre ne remplace jamais celle publiée par le joueur lui-même s'il est en
  ligne.
- Les noms de métiers ne voyagent pas : chaque client les affiche dans sa
  langue, et les empreintes restent identiques d'une langue à l'autre.
- **Note publique de guilde** : un officier écrit `alch300 cout250` dans la
  note de chaque membre (31 caractères), en gardant le texte déjà présent.
  Visible même sans l'add-on.
- Les fiches des membres partis sont retirées, seulement quand la liste de
  guilde est complète.

### 3.8 Les recettes et le catalogue

- Lecture à l'ouverture de la fenêtre de métier, gardée par perso.
- `IsPlayerSpell` ou `IsSpellKnown` sur l'identifiant de la recette sert de
  seconde preuve, sans ouvrir la fenêtre.
- **Catalogue embarqué** : pour forge, alchimie, ingénierie, cuir, couture
  et enchantement, la liste de toutes les recettes de Forever, avec l'objet fabriqué et le
  niveau de métier requis. Source : le site foreverchanges.pro. Les objets
  liés quand ramassés sont exclus, puisqu'on ne peut pas les donner.
- Le client fournit les noms et les icônes dans la langue du joueur. Les
  artisans partagent ce qu'ils ont lu. Les données reçues d'un officier sont
  gardées 30 jours, celles d'un membre 3 jours.
- S'y ajoute une table de 31 986 objets (nom français, nom anglais, icône),
  tirée des tables du client sur wago.tools.

### 3.9 Les demandes

Le cœur de GSF côté entraide, proche de nos « Commandes ».

- Types : starter, objet précis, craft, enchantement. Qui voit quoi dépend du
  type : un craft n'est vu que du demandeur, des artisans du métier et des
  officiers.
- Vie d'une demande : créée, **prise**, validée ou annulée. Le preneur peut se
  retirer : la demande redevient libre et garde son numéro.
- Pour prendre un craft, il faut le niveau de métier **et** la recette
  apprise. Sinon le bouton reste gris et l'info-bulle dit pourquoi.
- **Plusieurs donneurs** : chacun annonce ce qu'il apporte. Une barre
  « Reçu : 13/20 » est la même chez tout le monde.
- **Réception par courrier** : quand le demandeur retire de sa boîte l'objet
  envoyé par un membre, le compteur avance tout seul.
- Annuler ou refuser demande un motif court, montré au demandeur.
- Messages privés automatiques au demandeur ou au preneur, envoyés seulement
  par celui qui agit et seulement si l'autre est en ligne. La synchro ne les
  rejoue jamais.
- Limites : 10 demandes actives, 20 créations par 24 heures, quantité de 1 à
  20. Une demande s'éteint seule après 7 jours, ou quand le demandeur quitte
  la guilde.
- Chaque ligne montre l'icône de l'objet, son info-bulle, et le niveau de
  métier requis coloré selon le perso qui regarde.
- Une validée reste visible 60 minutes, puis disparaît de l'écran.

Règles de fusion, toutes pensées pour donner le même résultat partout :

- une demande fermée ne se rouvre jamais ;
- entre deux prises, la plus récente gagne, puis le nom ;
- entre deux fermetures, la plus ancienne gagne, puis l'annulation ;
- les fermées sont gardées 7 jours, puis une trace de suppression 60 jours
  (2 000 traces au plus) ;
- accepter ou refuser une ligne ne dépend **que** de la ligne, jamais de
  l'historique local. Une règle qui dépendait de l'historique a laissé deux
  clients en désaccord pour toujours : elle a été retirée.

### 3.10 La synchro des demandes

1. Le demandeur diffuse à la guilde `Q|jeton|empreinte`.
2. Ceux dont l'empreinte diffère proposent **en privé** `O|jeton|empreinte`,
   après un délai tiré du nom.
3. Le demandeur choisit une offre et tire les pages une à une, en privé :
   `GET|jeton|page`.
4. Les pages sont **figées** au début du transfert (5 000 octets chacune),
   demandes actives d'abord.
5. Un budget de 60 000 octets par minute protège celui qui sert. S'il est
   vide, il répond `WAIT` et le demandeur réessaie 10 secondes plus tard.
6. Deux relances, puis passage à une autre offre.

À retenir : les données ne sont **pas diffusées à toute la guilde**. Seul le
demandeur les reçoit. Chez nous, la réponse part sur le canal de guilde : tout
le monde la reçoit et la traite. C'est sans effet à 30 membres, coûteux à 300.

### 3.11 Réglages partagés

Une liste entière = un instantané daté, le dernier écrit gagne. Écrite par un
officier, envoyée à la guilde, redemandée à la connexion, et rediffusée par
les officiers avec leur battement pour que les absents rattrapent.

### 3.12 Le pont de bureau

La pièce maîtresse pour notre besoin « site et add-on synchronisés par le PC
d'un officier ».

**Du jeu vers le site.** L'add-on range ce qui doit partir dans sa
sauvegarde : liste de guilde (rang, classe, niveau, dernière connexion), codes
de liaison, signalements. Un programme sur le PC lit le fichier quand le jeu
l'écrit (déconnexion ou `/reload`) et l'envoie au site.

**Du site vers le jeu.** Le programme écrit un **second add-on**,
`GuildSelfForever_Data`, qui ne contient qu'une table de données. L'add-on
principal le déclare en dépendance facultative, lit la table à la connexion,
la **vérifie champ par champ** (schéma, guilde, tailles) et la garde en
mémoire seulement. Une donnée absente ou fausse est ignorée sans bruit.

**Ensuite, dans la guilde.** Celui qui a reçu des données du site les passe
aux autres par messages cachés. Un seul PC équipé suffit à servir la guilde.

Autour :

- Le pont est ouvert à tous les membres. Certains sont validés à la main sur
  le site comme collecteurs de confiance (« vigies »).
- **Preuve signée par le site** : le site signe (RSA 2048, SHA-256) une
  courte preuve pour chaque perso d'une vigie. Chaque client la vérifie avec
  la clé publique écrite dans l'add-on. Un membre ne peut donc pas se
  déclarer vigie. Le calcul est écrit en Lua pur.
- **Accusé de réception** : le site liste ce qu'il a reçu. L'add-on garde un
  signalement tant que le site ne l'a pas confirmé, et le renvoie à d'autres
  après 24 heures.
- **Lier un compte du site à un perso** : le site (ou Discord) donne un code,
  le joueur tape `/gsf link CODE` en jeu, le code part par message caché vers
  un officier, dont le pont l'envoie au site. Le jeu garantit qui a envoyé le
  code : c'est une preuve de possession du perso.
- Rappel une fois par session aux membres sans pont depuis 7 jours.
- L'ancien relais par des lignes techniques dans la discussion de guilde a
  été abandonné : peu fiable sur Forever, et visible de tous.

### 3.13 Qui a l'add-on

Le battement suffit. Un membre en ligne qui ne dit plus rien pendant
15 minutes est noté par deux témoins désignés par calcul. Pour GSF c'est un
signal de triche. Pour nous ce serait simplement « qui n'a pas encore
installé l'add-on ».

### 3.14 Plusieurs guildes en une

Un canal de discussion caché, protégé par mot de passe, relie toutes les
guildes de la fédération. Le site fournit son nom et son mot de passe par le
pont. Il ne transporte que des messages cachés, et il est retiré de toutes
les fenêtres de discussion. Détail utile : il n'est rejoint qu'après les
canaux par défaut du jeu, sinon il prend la place n° 1 et le jeu bloque.

Par-dessus : discussion de guilde commune entre guildes, et relais des
annonces.

### 3.15 Banques et effort de guerre

- Photos de la banque de guilde et des banques de persos approuvés, partagées
  et datées. Recherche d'un objet par nom, lien ou identifiant.
- **Effort de guerre** : les officiers fixent un seuil par ressource. Tant
  que les banques en ont moins, une ligne rouge dans l'info-bulle de l'objet
  demande à tous d'en déposer.
- Tri d'un onglet de banque de guilde, un déplacement à la fois.

### 3.16 Annonces à l'écran

Mort d'un perso en mode extrême, passage au niveau 60 (bannière, feux
d'artifice, son), message du jour, tombola. Une annonce est dédoublonnée par
une clé courte, pour que le message du joueur et celui d'un témoin n'en
fassent qu'une.

### 3.17 Interface et outils

- Thèmes par classe, police Saira avec retour possible à la police du jeu
  (certains la trouvent floue).
- Taille de la fenêtre par un curseur qui change l'échelle, pas la taille :
  toutes les pages restent dessinées pour une seule dimension.
- Échap ferme la dernière fenêtre ouverte, puis le panneau.
- Fenêtre de bienvenue au premier lancement.
- Étiquette de rang devant le nom dans la discussion de guilde
  (`ChatFrameUtil.AddSenderNameFilter`).
- `/gsf perf on` mesure le temps de chaque fonction, `/gsf diagnostic`
  liste les fonctions du jeu disponibles.
- Les interfaces en deux langues, choisies d'après le client.

## 4. Ce que ça change pour Dernier Rempart

### 4.1 Corrigé tout de suite (version 0.2.1)

| Problème dans la 0.2.0 | Effet en jeu | Correction |
|------------------------|--------------|------------|
| Le nom du perso était lu par `UnitName` puis collé au royaume. | L'auteur d'une sortie n'était pas retrouvé dans la liste de guilde : les sorties des officiers étaient **refusées** par les autres. Fiches et inscriptions sous un mauvais nom. | Nom complet « Prénom Nom » sans royaume. Toutes les formes d'un nom sont ramenées au nom de la liste de guilde. L'identifiant du perso tranche les homonymes. |
| Base rangée par royaume exact. | Deux persos de la guilde sur deux royaumes liés avaient deux bases. | Clé sans les numéros de royaume. |
| Membres hors ligne absents de la liste. | La sortie d'un officier déconnecté était refusée. | L'add-on demande les membres hors ligne. |
| Aucune garde sur les valeurs secrètes. | Erreurs possibles en combat. | Messages et liste de guilde ignorés quand ils sont secrets. La liste est relue après le combat. |
| « Chuchoter » ouvrait la zone de saisie. | Risque de blocage attribué à l'add-on. | Un nom à cliquer est affiché. |
| « Ouvrir la carte du monde » sans condition. | Refus en combat ou à la manette. | Le bouton explique pourquoi et n'essaie pas. |
| Erreurs avalées en silence. | Rien à montrer lors du premier test. | `/rempart rapport` : version du jeu, sauvegarde relue ou non, messages, erreurs, refus du jeu. |

### 4.2 Mécaniques à reprendre, par ordre de valeur

| # | Mécanique | Source | Ce que la guilde y gagne | Effort |
|---|-----------|--------|--------------------------|--------|
| 1 | **Pont automatique** : petit programme sur le PC d'un officier, et mini add-on de données `DernierRempart_Data` | R, G | Plus de copier-coller. Site et jeu se suivent à chaque connexion d'un officier. | Add-on : petit. Programme et site : moyen. |
| 2 | **Qui a l'add-on, dans quelle version**, et version exigée par les officiers | G | Savoir qui relancer. Éviter les versions mélangées. | Petit |
| 3 | **Accusé de lecture** d'une sortie : qui l'a vue, qui n'a pas répondu, qui n'a pas l'add-on | R | Le chef de raid voit qui relancer. | Petit |
| 4 | **Former le raid depuis une sortie** : état de chaque inscrit, inviter, continuer d'inviter, « inv » par chuchotement | R | Les 15 premières minutes d'un raid. | Moyen |
| 5 | **Présences** d'une soirée, renvoyées au site par le Pont | R | Assiduité sans saisie. | Moyen |
| 6 | **Codes compressés** par `C_EncodingUtil`, avec somme de contrôle | R | Codes et messages 3 à 5 fois plus courts. | Petit, mais change le format du Pont |
| 7 | **Annuler le dernier import** du Pont | R | Un mauvais code ne coûte rien. | Petit |
| 8 | **Catalogue de recettes embarqué**, avec niveau requis | G | « Personne ne l'a » complet dès le premier jour, sans attendre que chaque artisan ouvre son métier. | Moyen (données à fabriquer) |
| 9 | **Commandes à plusieurs donneurs**, compteur reçu/demandé, motif d'annulation, extinction après 7 jours | G | Les grosses demandes (tissu, minerai) se remplissent à plusieurs. | Moyen |
| 10 | **Lier son compte du site à son perso** par un code tapé en jeu | G | Le site sait à qui est chaque perso, sans confiance aveugle. | Petit côté add-on |
| 11 | **Métiers dans la note publique** de guilde | G | Visible même sans l'add-on. | Petit |
| 12 | **Annonces à l'écran** : rappel de sortie, niveau 60 | G | Vie de guilde. | Petit |
| 13 | **Réponses de synchro en privé**, par pages | G | Tient à plusieurs centaines de membres. | Moyen |
| 14 | **Banque de guilde** consultable et besoins dans l'info-bulle | G | « La guilde a besoin de… » se voit en ramassant l'objet. | Gros |
| 15 | **Canal caché** pour une guilde d'alts | G | Une seule guilde pour l'add-on. | Moyen |

Ce que nous avons déjà au même niveau, ou mieux : aperçu avant import,
fusion où le plus récent gagne, synchro par 16 empreintes (seuls les paquets
différents voyagent, là où GSF renvoie tout), un seul répondant par demande,
pause pendant les boss, lecture des recettes avec les mêmes garde-fous.

### 4.3 Ce qu'il ne faut pas reprendre

- Tout l'anti-triche de GSF : hors sujet, et source de la plupart de ses
  corrections d'urgence.
- Les lignes techniques dans la discussion de guilde : abandonnées par GSF.
- Les fenêtres de confirmation de Blizzard, encore utilisées par GSF et
  retirées par Raidify après des erreurs en jeu.
- La copie de secours dans les réglages du jeu : seulement si le test en jeu
  montre que la sauvegarde n'est pas relue.
- Le budget réseau de GSF (2 000 octets par seconde) : il compte sur les
  refus du jeu. Le nôtre reste sous la limite, comme celui de Raidify.

### 4.4 À vérifier en jeu

1. `/rempart rapport` après un `/reload` : « Sauvegarde : relue ».
2. Le nom affiché dans « Mes persos » est bien « Prénom Nom ».
3. Une sortie créée par un officier arrive chez un membre d'un autre royaume
   lié.
4. Aucun refus du jeu dans le rapport après une soirée (carte, épingles).
5. `C_EncodingUtil` répond : `/dump C_EncodingUtil ~= nil`.

## 5. Droits

Aucun des deux paquets n'a de licence : par défaut, tous droits réservés.

- Nous réécrivons les mécaniques à notre façon. Aucun fichier, aucune
  fonction n'est copié. Les corrections de la 0.2.1 sont du code neuf.
- Les données de recettes de GSF viennent de foreverchanges.pro et les
  objets de wago.tools. Pour un catalogue chez nous, il faut repartir de ces
  sources, pas des fichiers de GSF, et demander l'accord de foreverchanges.pro.
- Les bibliothèques jointes à Raidify (Ace3, LibDeflate, LibDBIcon) ont
  leurs propres licences libres. Nous n'en avons pas besoin.
- GSF cite l'add-on GreenWall (licence MIT) pour la discussion entre guildes
  et précise n'avoir copié aucun code des add-ons d'annonce de mort (GPL).
  La même prudence vaut pour nous.
