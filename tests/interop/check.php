<?php
// Test croisé : le site (PHP) lit un code fabriqué par l'add-on, puis fabrique
// un code que l'add-on relira. Usage : php check.php code_du_jeu.txt sortie_site.txt
require __DIR__ . '/../../tools/php/DrPont.php';

function check(bool $cond, string $msg): void
{
    if (!$cond) {
        fwrite(STDERR, "ÉCHEC : $msg\n");
        exit(1);
    }
    echo "  ok   $msg\n";
}

$payload = DrPont::decode(file_get_contents($argv[1]));
check($payload['src'] === 'jeu', 'le code vient du jeu');
check(isset($payload['events'][0]['t']) && $payload['events'][0]['t'] === 'Repaire d’Onyxia', 'titre accentué intact');
$signup = null;
foreach ($payload['signups'] as $s) {
    if ($s['c'] === 'Brumelune-Rempart') {
        $signup = $s;
    }
}
check($signup !== null && $signup['m'] === 'je ramène des fioles « bleues »', 'petit mot intact');
check(DrPont::keyOf('signups', $signup) === $signup['e'] . '|Brumelune-Rempart', 'clé d\'inscription');
$recipes = $payload['recipes'][0] ?? null;
check($recipes !== null && $recipes['l'] === [3451] && $recipes['pn'] === 'Alchimie', 'recettes lues');
$wish = $payload['orders'][0] ?? null;
check($wish !== null && $wish['sp'] === 17635 && $wish['k'] === 'recette', 'recette recherchée');
foreach (['events', 'signups', 'chars', 'recipes', 'orders', 'votes'] as $ds) {
    $good = true;
    foreach ($payload[$ds] ?? [] as $rec) {
        $good = $good && DrPont::keyOf($ds, $rec) !== null && is_int($rec['u']);
        foreach ($rec as $k => $_) {
            $good = $good && $k[0] !== '_';
        }
    }
    check($good, "$ds : clé et date présentes, aucun champ local (" . count($payload[$ds] ?? []) . ")");
}

// Fusion côté site : coller deux fois ne change rien.
[$base, $stats] = DrPont::mergeAll([], $payload);
check($stats['new'] > 0 && $stats['rejected'] === 0, 'première fusion : tout est pris');
[$base, $stats] = DrPont::mergeAll($base, $payload);
check($stats['new'] === 0 && $stats['same'] > 0, 'deuxième fusion : rien ne compte deux fois');

// Le canon PHP est celui de l'add-on : même texte, octet pour octet.
$lua = json_decode(base64_decode(substr(trim(file_get_contents($argv[1])), 4)), true);
check(DrPont::canon($lua['signups'][0]) === DrPont::canon($payload['signups'][0]), 'canon stable');

// Le site renvoie une sortie, une inscription faite sur le site et une suppression.
$now = time();
$event = $payload['events'][0];
$site = [
    'at' => $now - 60,
    'events' => [
        ['id' => 's77', 't' => 'Hyjal Summit', 'k' => 'raid', 'd' => $now + 3 * 86400, 'nt' => 2, 'nh' => 3, 'nd' => 5,
         'cap' => 10, 'st' => 'open', 'rdv' => 'Entrée du mont Hyjal', 'u' => $now - 120],
    ],
    'signups' => [
        ['e' => 's77', 'c' => 'Galdrin-Rempart', 'cl' => 'PALADIN', 'r' => 'T', 's' => 'yes', 'u' => $now - 100,
         'by' => 'Galdrin-Rempart'],
    ],
    'orders' => [
        ['id' => $wish['id'], 'del' => 1, 'u' => $now - 30],
    ],
];
file_put_contents($argv[2], DrPont::encode($site));
check(strncmp(file_get_contents($argv[2]), 'DR2:', 4) === 0, 'code du site fabriqué');

// Erreurs claires.
foreach (['' => 'Colle', 'DR1:abc' => 'DR1', 'bonjour' => 'DR2'] as $bad => $word) {
    try {
        DrPont::decode($bad);
        check(false, "code « $bad » refusé");
    } catch (InvalidArgumentException $e) {
        check(strpos($e->getMessage(), $word) !== false, "code « $bad » refusé avec un message clair");
    }
}
echo "PHP : tout est bon\n";
