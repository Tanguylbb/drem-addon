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

**Artisans** — chaque artisan ouvre sa fenêtre de métier une fois : ses
recettes sont lues et partagées. On cherche une recette et on voit qui sait la
faire et qui est en ligne, puis on lui demande en un clic (demandée, acceptée,
faite). La liste « Recettes recherchées » garde ce que la guilde aimerait
avoir (un enchantement, une potion…) : on l'achète, on la trouve ou on
l'achète entre nous, puis un artisan l'apprend. Chacun soutient avec
« Moi aussi », et la demande se ferme toute seule quand quelqu'un l'apprend.
« Personne ne l'a » montre les recettes d'un métier que personne ne connaît.

**Carte** — où sont les membres de la guilde : sur la carte de la zone dans
l'onglet Carte, et sur la carte du monde du jeu. Les positions ne circulent
que quand quelqu'un regarde une carte, jamais en donjon, en raid ou en champ de
bataille, et chacun peut couper le partage (`/rempart position`).

**Mes persos** — la fiche de chaque perso (classe, niveau, spé, rôle, métiers)
est lue toute seule et partagée avec la guilde.

**Pont** (officiers) — un code à copier-coller relie le jeu et le site, dans
les deux sens, en moins d'une minute. Le point en haut de la fenêtre dit si les
données du site sont fraîches (vert, orange, rouge). Format :
[docs/PONT.md](docs/PONT.md).

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
| `/rempart sorties` · `artisans` · `carte` · `persos` · `pont` | Ouvrir un onglet |
| `/rempart synchro` | Redemander les dernières données à la guilde |
| `/rempart position` | Partager ou non sa position |
| `/rempart minimap` | Afficher ou cacher le bouton de la minicarte |
| `/rempart version` | Version de l'add-on |

Clic sur le blason de la minicarte : ouvrir. Clic droit : Artisans.

## Pour les officiers

- Les officiers sont les rangs 0 et 1 de la guilde. Le chef de guilde change
  le seuil en bas de l'onglet Pont ; le réglage est partagé à tous.
- Seuls les officiers créent des sorties : une sortie envoyée par un autre est
  refusée par les add-ons.
- La confiance repose sur la guilde : un membre qui trafiquerait son add-on
  pourrait envoyer de fausses inscriptions. Le site reste la référence.

## Développer

```
lua5.1 tests/run.lua          # 78 tests hors jeu, avec un faux client WoW
bash tests/interop/run.sh     # le PHP du site et l'add-on se relisent
luacheck DernierRempart       # vérification statique
```

Le faux client (`tests/harness.lua`) charge l'add-on comme le jeu, plusieurs
fois, et fait circuler les messages de guilde entre les « joueurs » : la
synchro, les droits officiers, la pause en combat et le Pont sont testés de
bout en bout. Ce qui demande le vrai jeu est dans
[docs/TEST-EN-JEU.md](docs/TEST-EN-JEU.md).

```
DernierRempart/
  Core/      démarrage, outils, JSON, Base64, magasin, guilde, messages, synchro
  Modules/   fiche perso, sorties, artisans, carte, pont
  UI/        charte, composants, fenêtre et onglets, minicarte, épingles
  Media/     blason, pictos de rôle, polices Marcellus et Open Sans (licence OFL)
tools/php/   DrPont.php : lecture et écriture des codes DR2 pour le site
```

Polices : Marcellus et Marcellus SC (Brian J. Bonislawsky), Open Sans (The
Open Sans Project Authors), sous SIL Open Font License, fournies avec leur
licence dans `DernierRempart/Media/Fonts`.
