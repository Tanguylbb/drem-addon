# Dernier Rempart — l'add-on de la guilde

Add-on World of Warcraft: Forever de la guilde **Dernier Rempart**, relié au
site [dernier-rempart.eu](https://dernier-rempart.eu). Il remplace les add-ons
de raid tout faits : les sorties, les inscriptions, les artisans et la fiche de
chaque perso sont les mêmes en jeu et sur le site, sans rien taper deux fois.
Il reprend la charte des maquettes v2 du site (fond Nuit, titres dorés en
Marcellus, texte en Open Sans, Sarcelle quand c'est plein, Ambre quand il
manque du monde).

## Ce qu'il fait

**Sorties** — le calendrier des raids, donjons et soirées sur 60 jours. On
s'inscrit en un clic (Présent, Peut-être, Remplaçant, Absent) avec son perso,
son rôle et un petit mot. Les compteurs tanks, soins et DPS montrent ce qui
manque. Les officiers créent, modifient, ferment ou annulent les sorties en
jeu ; celles du site arrivent par le Pont.

**Sorties** (suite) — une ligne dit où en est la synchro (« À jour : dernière
réponse de … ») et un bouton « Redemander à la guilde » la relance sans
commande. Pour chaque sortie : combien ont répondu, combien n'ont pas répondu,
combien n'ont pas l'add-on (à relancer sur Discord).

**Artisans** — chaque artisan ouvre sa fenêtre de métier une fois : ses
recettes sont lues et partagées. L'onglet montre **toute la liste d'un métier,
rangée par type de craft** (Sacs, Robes…) en dossiers qu'on ouvre et ferme,
y compris les recettes que personne n'a apprises. Filtres « Tout », « Il me
manque », « Personne ne l'a ». Sur une recette que personne ne sait faire, un
**+1** dit « je voudrais que la guilde l'achète » : la fiche montre qui la
veut, où la trouver (renseigné par les membres) et qui pourrait l'apprendre.
Quand quelqu'un sait la faire, on le voit en ligne et on lui demande en un clic
(demandée, acceptée, faite). La liste « Recettes recherchées » est la liste
d'achat des officiers, rangée par nombre de +1.

**Effort de guerre** — les officiers fixent des objectifs (une somme d'or, ou
des objets pour un raid) avec une date. Quand un membre ouvre la **banque de
guilde**, l'add-on lit son journal : les dépôts se rattachent tout seuls aux
objectifs, sans rien déclarer. Un dépôt qui hésite entre deux objectifs est
« à classer » par un officier. Les retraits ne comptent pas. Un don qui ne
passe pas par la banque se déclare à la main. Les officiers choisissent si
tout le monde voit les noms et les montants, ou seulement les totaux.
Le journal de la banque se lit seulement banque ouverte et ne garde que les
derniers mouvements : plus il y a de membres qui l'ouvrent, moins il en manque.
`/rempart banque` dit ce que le jeu rend.

**Carte** — où sont les membres de la guilde : sur la carte de la zone dans
l'onglet Carte, et sur la carte du monde du jeu. Trois chiffres disent
pourquoi la carte est vide (en ligne, avec l'add-on, qui partage), et chaque
membre a sa raison : sur la carte, autre zone, en donjon, position coupée, pas
d'add-on. Les positions ne circulent que quand quelqu'un regarde une carte,
jamais en donjon, en raid ou en champ de bataille, et chacun peut couper le
partage depuis l'onglet (ou `/rempart position`).

**Mes persos** — la fiche de chaque perso (classe, niveau, spé, rôle, métiers)
est lue toute seule et partagée avec la guilde. Les recettes ne se lisent que
quand le joueur ouvre un métier (le jeu ne laisse pas l'add-on le faire à sa
place) : l'onglet dit quels métiers sont **lus** et lesquels sont **à ouvrir**,
et une seule ligne dans le chat le rappelle à la connexion.

**Pont** (officiers) — l'état du **relais automatique** depuis le PC d'un
officier (ce qui est parti au site, ce qui est arrivé, qui assure le relais et
qui est en secours), et le copier-coller qui reste en secours, dans les deux
sens, en moins d'une minute. Le point en haut de la fenêtre dit si les données
du site sont fraîches (vert, orange, rouge). Formats :
[docs/PONT.md](docs/PONT.md) (codes) et [docs/RELAIS.md](docs/RELAIS.md)
(le petit programme du relais).

## Comment les données circulent

Un add-on n'a pas accès à internet. Entre les joueurs connectés, tout passe par
le canal de guilde des add-ons : chaque changement part tout de suite, et à la
connexion l'add-on compare ses données avec celles d'un membre en ligne pour
rattraper ce qu'il a manqué. Entre le jeu et le site, un officier fait le Pont.
Partout, la version la plus récente gagne, et rien ne compte deux fois.

Pendant un combat de boss, les messages entre add-ons sont bloqués (règles de
Midnight, reprises par Forever) : ce qui est fait pendant le combat part
juste après.

## Installer

1. Télécharger le dossier `DernierRempart` (CurseForge, ou l'archive du dépôt).
2. Le copier dans le dossier `Interface/AddOns` du client **Forever** (pas celui
   de Retail ni de Classic).
3. Relancer le jeu. `/rempart` ouvre la fenêtre.

Le `.toc` vise l'interface **16001** (client Forever). Si le jeu marque
l'add-on comme périmé, taper `/dump select(4, GetBuildInfo())` et mettre ce
nombre dans `DernierRempart/DernierRempart.toc`.

## Commandes

| Commande | Effet |
|----------|-------|
| `/rempart` | Ouvrir ou fermer la fenêtre |
| `/rempart sorties` · `artisans` · `carte` · `effort` · `persos` · `pont` | Ouvrir un onglet |
| `/rempart synchro` | Redemander les dernières données à la guilde |
| `/rempart position` | Partager ou non sa position |
| `/rempart banque` | Ce que le jeu rend du journal de la banque de guilde (banque ouverte) |
| `/rempart minimap` | Afficher ou cacher le bouton de la minicarte |
| `/rempart version` | Version de l'add-on |
| `/rempart rapport` | État de l'add-on, à envoyer si quelque chose cloche |

Clic sur le blason de la minicarte : ouvrir. Clic droit : Artisans.

## Particularités de Forever

Un perso s'appelle « Prénom Nom », sans royaume : c'est ce nom qui sert
partout (inscriptions, fiches, recettes). Une guilde s'étale sur plusieurs
royaumes liés et tout le monde partage la même base. L'add-on demande au jeu
les membres hors ligne de la liste de guilde, pour reconnaître les officiers
déconnectés. Ce que le client refuse aux add-ons est détaillé dans
[docs/RETRO-INGENIERIE.md](docs/RETRO-INGENIERIE.md).

## Pour les officiers

- Les officiers sont les rangs 0 et 1 de la guilde. Le chef de guilde change
  le seuil en bas de l'onglet Pont ; le réglage est partagé à tous.
- Seuls les officiers créent des sorties : une sortie envoyée par un autre est
  refusée par les add-ons.
- La confiance repose sur la guilde : un membre qui trafiquerait son add-on
  pourrait envoyer de fausses inscriptions. Le site reste la référence.

## Développer

```
lua5.1 tests/run.lua          # tests hors jeu, avec un faux client WoW
bash tests/interop/run.sh     # le PHP du site et l'add-on se relisent
luacheck DernierRempart       # vérification statique
```

Le faux client (`tests/harness.lua`) charge l'add-on comme le jeu, plusieurs
fois, et fait circuler les messages de guilde entre les « joueurs » : la
synchro, les droits officiers, la pause en combat, les noms « Prénom Nom »
de Forever et le Pont sont testés de bout en bout. Ce qui demande le vrai jeu est dans
[docs/TEST-EN-JEU.md](docs/TEST-EN-JEU.md).

```
DernierRempart/
  Core/      démarrage, outils, JSON, Base64, magasin, guilde, messages, synchro
  Modules/   fiche perso, sorties, artisans, carte, effort de guerre, banque, pont
  UI/        charte, composants, fenêtre et onglets, minicarte, épingles
  Media/     blason, pictos de rôle, polices Marcellus et Open Sans (licence OFL)
tools/php/   DrPont.php : lecture et écriture des codes DR2 pour le site
tools/relais/ gabarit du mini add-on de données déposé par le relais
```

Polices : Marcellus et Marcellus SC (Brian J. Bonislawsky), Open Sans (The
Open Sans Project Authors), sous SIL Open Font License, fournies avec leur
licence dans `DernierRempart/Media/Fonts`.
