# Le Pont : format des codes DR2

Ce document est le contrat entre l'add-on et **dernier-rempart.eu**. Un add-on
n'a pas accès à internet : les données passent par un code que l'officier
copie-colle, dans un sens ou dans l'autre. Le site doit savoir lire et écrire
ce format. La classe [`tools/php/DrPont.php`](../tools/php/DrPont.php) le fait
déjà : elle se copie telle quelle dans le site.

## Le code

```
DR2:<JSON encodé en Base64 standard>
```

- `DR2:` en tête, puis du Base64 standard (RFC 4648, alphabet `+/`, avec `=`).
  Le jeu accepte aussi l'alphabet URL (`-_`) et ignore les espaces et retours
  à la ligne.
- Le JSON est en UTF-8 brut (les accents ne sont pas échappés).
- `DR1:` reste le code de fiche perso de la page « Importer depuis le jeu ».
  L'onglet Pont le refuse avec un message clair.

## L'enveloppe

| Champ   | Sens |
|---------|------|
| `v`     | Version du format : `2`. Toute autre valeur est refusée. |
| `src`   | `"jeu"` (fabriqué par l'add-on) ou `"site"`. |
| `at`    | Date du code (secondes depuis 1970, heure du serveur). Côté site : date des données du site, sert au point vert, orange ou rouge en jeu. |
| `by`    | Perso de l'officier qui a fabriqué le code (codes du jeu). |
| `g`     | Nom de la guilde (codes du jeu). |
| `av`    | Version de l'add-on (codes du jeu). |
| `since` | Codes du jeu : le code contient ce qui a changé depuis cette date (0 = tout). |
| `events`, `signups`, `chars`, `recipes`, `orders`, `votes`, `meta`, `goals`, `gifts` | Listes d'enregistrements, détaillées plus bas. Une liste vide est absente. |

Ce que chaque sens transporte :

- **Jeu → site** : `events`, `signups`, `chars`, `recipes`, `orders`, `votes`, `goals`, `gifts`.
- **Site → jeu** : `events`, `signups`, `orders`, `votes`, `meta`, `goals`.
  Les enregistrements sans `by` sont signés `"site"` à l'import.

## La règle de fusion

Chaque enregistrement porte :

- `u` : date de sa dernière modification, en secondes (obligatoire) ;
- `by` : qui l'a modifié (nom complet du perso, ou `"site"`) ;
- `del` : `1` si l'enregistrement est supprimé (pierre tombale, garder les
  champs de la clé).

**La version la plus récente gagne** (`u` le plus grand). À égalité de `u`, on
compare le JSON canonique (clés triées, UTF-8 brut, sans les champs qui
commencent par `_`) : le plus grand dans l'ordre des octets gagne. Ainsi
coller deux fois le même code ne change rien, et tout le monde converge vers
la même version.

Le site doit donc :

1. garder `u` (et `by`) sur chaque ligne qu'il stocke ;
2. mettre `u = time()` à chaque modification faite sur le site ;
3. renvoyer les suppressions sous forme de pierre tombale (`del: 1`) ;
4. ignorer une ligne reçue plus ancienne que la sienne.

L'add-on refuse une date à plus d'une heure dans le futur.

## Les enregistrements

Les clés sont courtes pour garder les codes petits. Les champs facultatifs
sont absents quand ils sont vides.

### `events` : sorties — clé `id`

| Champ | Type | Sens |
|-------|------|------|
| `id`  | texte | Identifiant. Le site choisit le sien (`s42`) ; le jeu crée `g…`. |
| `t`   | texte (80) | Titre. |
| `k`   | texte | `raid`, `donjon`, `soiree` ou `autre`. |
| `d`   | nombre | Début (horodatage). |
| `dur` | nombre | Durée en minutes. |
| `cap` | nombre | Places. |
| `nt`, `nh`, `nd` | nombres | Tanks, soins, DPS voulus. |
| `lead` | texte | Chef de raid. |
| `rdv` | texte (120) | Rendez-vous. |
| `note` | texte (500) | Consignes. |
| `st`  | texte | `open`, `closed` (inscriptions fermées) ou `cancelled`. |
| `lock` | nombre | Fermeture automatique des inscriptions (facultatif). |
| `src` | texte | `site` ou `jeu`. |

En jeu, seuls les officiers créent et modifient les sorties.

### `signups` : inscriptions — clé `e|c`

| Champ | Sens |
|-------|------|
| `e`   | Id de la sortie. |
| `c`   | Perso, nom complet. Sur Forever : `Prénom Nom`, sans royaume. |
| `cl`  | Classe (`PALADIN`, `MAGE`…). |
| `r`   | Rôle : `T` tank, `H` soins, `D` DPS. |
| `s`   | `yes` présent, `maybe` peut-être, `bench` remplaçant, `no` absent. |
| `m`   | Petit mot (60). |
| `acc` | Identifiant du compte (au hasard, sert à repérer les persos d'un même joueur). |

Un seul perso par compte et par sortie : en changer supprime l'autre (pierre
tombale).

### `chars` : fiches perso — clé `n`

`n` nom complet (`Prénom Nom` sur Forever), `cl` classe, `ra` race, `lv` niveau, `sp` spé, `r` rôle,
`g` guilde, `rk` rang, `acc` compte, `p` métiers : liste de
`{ "id": 171, "nm": "Alchimie", "lv": 300, "mx": 300 }`.

### `recipes` : recettes d'un perso — clé `c|p`

`c` perso, `p` identifiant du métier (171 Alchimie, 333 Enchantement…),
`pn` nom du métier, `lv`/`mx` niveau, `l` liste triée des recettes apprises
(identifiants de sort du jeu ; un nombre négatif est un identifiant d'objet).

### `catalog` : toutes les recettes d'un métier — clé `p`

Échangé entre add-ons (pas envoyé au site). `p`, `pn` (métier), `l` (toutes les
recettes vues dans une fenêtre de métier, apprises ou non) et, depuis la 0.3,
`g` : les mêmes rangées par type de craft, `[{ "n": "Sacs", "l": [id, …] }, …]`.
C'est ce qui permet de lister aussi les recettes que personne n'a apprises.

### `orders` : commandes — clé `id`

- `k = "recette"` : une recette que la guilde cherche. `s` :
  `cherchee`, `trouvee` (on a la recette, reste à l'apprendre), `apprise`,
  `abandonnee`.
- `k = "craft"` : une demande de fabrication à un artisan. `s` :
  `demandee`, `acceptee`, `faite`, `annulee`.

Autres champs : `sp` sort, `it` objet, `link` lien du jeu, `nm` nom, `p`/`pn`
métier, `req` demandeur, `to` artisan visé (craft), `m` mot (200), `who` qui
l'a apprise ou faite.

Pour une recette recherchée (`k = "recette"`), deux champs de la 0.3 disent
**où la trouver** : `wh` (texte libre, 120 caractères : « Marchand de patrons,
Hurlevent ») et `wb` (le perso qui l'a renseigné). Le « +1 » d'un membre sur une
recette que personne ne sait faire est un `votes` sur cette commande (la
commande est créée au premier +1).

### `votes` : soutiens « moi aussi » — clé `o|c`

`o` id de la commande, `c` perso.

### `goals` : objectifs de l'effort de guerre — clé `id`

Fixés par les officiers (le jeu refuse un objectif dont l'auteur n'est pas
officier ou `"site"`). Le site peut en créer : ils arrivent en jeu.

| Champ | Sens |
|-------|------|
| `id`  | Identifiant (texte unique, 200 caractères au plus). |
| `t`   | Titre (80). |
| `k`   | `"or"` (une somme) ou `"objet"` (des objets, pour un raid par exemple). |
| `amt` | La cible : en **cuivres** pour l'or (1 po = 10 000), en quantité pour un objet. |
| `it`, `nm` | Objet attendu : identifiant et nom (`k = "objet"`). |
| `tag` | Petite étiquette (40) : « Cœur du Magma ». |
| `from` | Début (secondes). Les dons d'avant ne comptent pas. |
| `to`  | Fin, facultative. Fermer un objectif la met à « maintenant ». |
| `st`  | `"open"` ou `"closed"`. |

### `gifts` : dons — clé `id`

Un don est **lu dans le journal de la banque de guilde** par le membre qui
ouvre la banque (`src = "bank"`), ou déclaré à la main (`src = "hand"`).

| Champ | Sens |
|-------|------|
| `id`  | Identifiant (`b…` pour la banque, `h…` à la main). |
| `c`   | Le perso qui a donné. |
| `k`   | `"or"` ou `"objet"`. |
| `a`   | Cuivres (or) ou quantité (objets). |
| `it`, `nm` | L'objet (`k = "objet"`). |
| `at`  | Quand, **à l'heure près** (le journal de la banque donne « il y a N heures »). |
| `src` | `"bank"` ou `"hand"`. |
| `rd`  | Qui a lu la ligne dans la banque (`src = "bank"`). |
| `tab` | Onglet de la banque (objets). |
| `g`   | Objectif choisi à la main par un officier ; `"-"` : ne compte pour aucun. |
| `n`   | Petit mot (120), déclarations à la main. |

**Compter sans doublon** (à reprendre côté site) : plusieurs membres lisent le
même journal et estiment l'heure à une heure près, donc la même ligne peut
exister sous plusieurs `id`. Pour les dons `src = "bank"` : regrouper ceux qui
ont le même `c`, `k`, `a`, `it` et dont les `at` se suivent à 2 heures près
(3 jours près s'ils ont plus de 25 jours) ; dans chaque groupe, compter le plus
grand nombre de lignes d'**un même** `rd`. Les dons `src = "hand"` se comptent
un par un.

**Rattacher un don à un objectif** : le `g` du don s'il y en a un ; sinon
l'unique objectif de même sorte (et même objet) dont la période `from` → `to`
contient `at`. Plusieurs objectifs possibles : « à classer » par un officier.

### `meta` — clé `id`

- `id = "site"` : `at` date des données du site, `imp` officier qui a importé.
  Posé par l'add-on à l'import, sert au point de fraîcheur.
- `id = "config"` : `officerRank`, dernier rang compté comme officier
  (0 = chef de guilde). Réglé en jeu par le chef de guilde.
- `id = "effort"` : `vis` = `"all"` ou `"officers"`, qui voit les noms et les
  montants dans l'onglet Effort de guerre (réglage d'affichage).
- `id = "bank"` : `at`, `by`, `n`, `nw` : dernière lecture du journal de la
  banque (quand, par qui, combien de lignes, combien de nouvelles).
- `id = "relay:<perso>"` : `at` : cet officier a appliqué des données déposées
  par le relais automatique. Sert à montrer qui assure le relais.

## Exemple

```json
{
  "v": 2, "src": "site", "at": 1794301200,
  "events": [
    { "id": "s42", "t": "Repaire d’Onyxia", "k": "raid", "d": 1794682800, "dur": 120,
      "cap": 40, "nt": 4, "nh": 10, "nd": 26, "st": "open", "u": 1794300000 }
  ],
  "signups": [
    { "e": "s42", "c": "Galdrin-Rempart", "cl": "PALADIN", "r": "T", "s": "yes",
      "u": 1794300100, "by": "Galdrin-Rempart" }
  ]
}
```

## Côté site, en PHP

```php
require 'DrPont.php';

// Jeu -> site : l'officier colle le code.
$payload = DrPont::decode($_POST['code']);          // lève InvalidArgumentException
[$base, $stats] = DrPont::mergeAll($base, $payload); // $base[jeu][clé] => enregistrement
// $stats = ['new' => …, 'same' => …, 'older' => …, 'rejected' => …] : à montrer avant de valider.

// Site -> jeu : le code à afficher sur la page Pont jeu.
echo DrPont::encode(['events' => $sorties, 'signups' => $inscriptions, 'at' => time()]);
```

Le test croisé `tests/interop/run.sh` vérifie que le PHP lit les codes de
l'add-on et que l'add-on relit ceux du PHP, accents compris.

## Relais automatique (0.3)

L'add-on garde dans sa sauvegarde (`WTF/Account/<COMPTE>/SavedVariables/DernierRempart.lua`)
le code à envoyer au site, dans `DernierRempartDB.outbox` :
`{ code = "DR2:…", at = <heure du code>, n = <lignes>, relay = true }`. Il le
prépare à chaque déconnexion et à chaque `/reload`, avec **tout ce qui a changé
depuis ce que le site a déjà reçu** (voir `sent.at` ci-dessous).

Un petit programme sur le PC d'un officier l'envoie au site, puis dépose un
mini add-on `DernierRempart_Data` avec ce que le site a de nouveau. L'add-on le
lit à la connexion et au `/reload`. Le programme et ses garde-fous sont décrits
dans [`RELAIS.md`](RELAIS.md).

```lua
-- Interface\AddOns\DernierRempart_Data\Data.lua (écrit par le relais)
DernierRempartData = {
  v = 1,
  at = 1794300000,                 -- heure des données du site
  code = "DR2:…",                  -- site -> jeu : un code DR2 ordinaire
  sent = {                         -- jeu -> site : ce que le site a bien reçu
    at = 1794299000,               -- l'heure (`at`) du code accepté
    when = 1794299900,             -- quand le relais l'a envoyé
    counts = { signups = 3, orders = 1, chars = 2 },
  },
}
```

L'add-on n'applique `code` que si le joueur est officier, vérifie chaque
champ (version, taille, forme) et n'applique un même `at` qu'une fois. Le
copier-coller reste en secours et fait exactement le même travail.
