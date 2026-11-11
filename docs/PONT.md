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
| `events`, `signups`, `chars`, `recipes`, `orders`, `votes`, `meta` | Listes d'enregistrements, détaillées plus bas. Une liste vide est absente. |

Ce que chaque sens transporte :

- **Jeu → site** : `events`, `signups`, `chars`, `recipes`, `orders`, `votes`.
- **Site → jeu** : `events`, `signups`, `orders`, `votes`, `meta`.
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

### `orders` : commandes — clé `id`

- `k = "recette"` : une recette que la guilde cherche. `s` :
  `cherchee`, `trouvee` (on a la recette, reste à l'apprendre), `apprise`,
  `abandonnee`.
- `k = "craft"` : une demande de fabrication à un artisan. `s` :
  `demandee`, `acceptee`, `faite`, `annulee`.

Autres champs : `sp` sort, `it` objet, `link` lien du jeu, `nm` nom, `p`/`pn`
métier, `req` demandeur, `to` artisan visé (craft), `m` mot (200), `who` qui
l'a apprise ou faite.

### `votes` : soutiens « moi aussi » — clé `o|c`

`o` id de la commande, `c` perso.

### `meta` — clé `id`

- `id = "site"` : `at` date des données du site, `imp` officier qui a importé.
  Posé par l'add-on à l'import, sert au point de fraîcheur.
- `id = "config"` : `officerRank`, dernier rang compté comme officier
  (0 = chef de guilde). Réglé en jeu par le chef de guilde.

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

## Relais automatique (plus tard)

À chaque code généré, l'add-on garde le dernier dans sa sauvegarde
(`WTF/Account/<COMPTE>/SavedVariables/DernierRempart.lua`, champ
`DernierRempartDB.outbox`). Un petit programme chez un officier volontaire
pourra le lire et l'envoyer au site tout seul, si le copier-coller prend plus
de 5 minutes par semaine.
