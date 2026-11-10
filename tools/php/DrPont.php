<?php
/**
 * Codec de référence du Pont jeu <-> site (codes « DR2: »), pour dernier-rempart.eu.
 *
 * Le format est décrit dans docs/PONT.md. Cette classe ne dépend de rien :
 * elle se copie telle quelle dans le site.
 *
 *   $payload = DrPont::decode($codeColleParLOfficier);   // jeu -> site
 *   $code    = DrPont::encode($payload);                  // site -> jeu
 *   [$base, $stats] = DrPont::mergeAll($base, $payload); // fusion « le plus récent gagne »
 */
final class DrPont
{
    public const MAGIC = 'DR2:';
    public const FORMAT = 2;

    /** Jeux de données échangés, et les champs qui forment la clé de chaque enregistrement. */
    public const KEY_FIELDS = [
        'events'  => ['id'],
        'signups' => ['e', 'c'],
        'chars'   => ['n'],
        'recipes' => ['c', 'p'],
        'catalog' => ['p'],
        'orders'  => ['id'],
        'votes'   => ['o', 'c'],
        'meta'    => ['id'],
    ];

    /** Lit un code collé. Lève InvalidArgumentException avec un message en français. */
    public static function decode(string $code): array
    {
        $code = preg_replace('/\s+/', '', $code);
        if ($code === '') {
            throw new InvalidArgumentException("Colle d'abord le code du jeu.");
        }
        if (strncmp($code, 'DR1:', 4) === 0) {
            throw new InvalidArgumentException('Ce code DR1 est une fiche perso, pas un code du Pont (DR2).');
        }
        if (strncmp($code, self::MAGIC, 4) !== 0) {
            throw new InvalidArgumentException('Ce n\'est pas un code du Pont : il doit commencer par DR2:.');
        }
        $raw = base64_decode(strtr(substr($code, 4), '-_', '+/'), true);
        if ($raw === false) {
            throw new InvalidArgumentException('Le code est abîmé : recopie-le en entier depuis le jeu.');
        }
        $payload = json_decode($raw, true);
        if (!is_array($payload)) {
            throw new InvalidArgumentException('Le code est incomplet ou abîmé : recopie-le en entier.');
        }
        if ((int)($payload['v'] ?? 0) !== self::FORMAT) {
            throw new InvalidArgumentException('Version du code inconnue : mets le site ou l\'add-on à jour.');
        }
        return $payload;
    }

    /** Fabrique un code à coller dans le jeu (onglet Pont). */
    public static function encode(array $payload): string
    {
        $payload['v'] = self::FORMAT;
        $payload['src'] = $payload['src'] ?? 'site';
        $payload['at'] = $payload['at'] ?? time();
        return self::MAGIC . base64_encode(self::canon($payload));
    }

    /** Clé d'un enregistrement, ou null s'il lui manque un champ. */
    public static function keyOf(string $ds, array $rec): ?string
    {
        if (!isset(self::KEY_FIELDS[$ds])) {
            return null;
        }
        $parts = [];
        foreach (self::KEY_FIELDS[$ds] as $f) {
            if (!isset($rec[$f]) || $rec[$f] === '') {
                return null;
            }
            $parts[] = (string)$rec[$f];
        }
        return implode('|', $parts);
    }

    /** JSON canonique : clés triées, UTF-8 brut, champs « _ » ignorés (identique à l'add-on). */
    public static function canon($value): string
    {
        return json_encode(self::sortKeys($value), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }

    private static function sortKeys($v)
    {
        if (!is_array($v)) {
            return $v;
        }
        if ($v === [] || array_keys($v) === range(0, count($v) - 1)) {
            return array_map([self::class, 'sortKeys'], $v);
        }
        $out = [];
        foreach ($v as $k => $item) {
            if (is_string($k) && $k !== '' && $k[0] === '_') {
                continue;
            }
            $out[(string)$k] = self::sortKeys($item);
        }
        ksort($out, SORT_STRING);
        return $out;
    }

    /** $a est-il plus récent que $b ? Date « u » d'abord, puis texte canonique pour départager. */
    public static function isNewer(array $a, ?array $b): bool
    {
        if ($b === null) {
            return true;
        }
        $ua = (int)($a['u'] ?? 0);
        $ub = (int)($b['u'] ?? 0);
        if ($ua !== $ub) {
            return $ua > $ub;
        }
        return strcmp(self::canon($a), self::canon($b)) > 0;
    }

    /**
     * Fusionne un code reçu dans une base indexée [jeu de données][clé] => enregistrement.
     * Rend [base fusionnée, statistiques]. Coller deux fois le même code ne change rien.
     */
    public static function mergeAll(array $base, array $payload): array
    {
        $stats = ['new' => 0, 'same' => 0, 'older' => 0, 'rejected' => 0];
        foreach (self::KEY_FIELDS as $ds => $_) {
            if (!isset($payload[$ds]) || !is_array($payload[$ds])) {
                continue;
            }
            foreach ($payload[$ds] as $rec) {
                if (!is_array($rec) || !isset($rec['u']) || !is_numeric($rec['u'])) {
                    $stats['rejected']++;
                    continue;
                }
                $key = self::keyOf($ds, $rec);
                if ($key === null) {
                    $stats['rejected']++;
                    continue;
                }
                $old = $base[$ds][$key] ?? null;
                if ($old !== null && self::canon($old) === self::canon($rec)) {
                    $stats['same']++;
                } elseif (self::isNewer($rec, $old)) {
                    $base[$ds][$key] = $rec;
                    $stats['new']++;
                } else {
                    $stats['older']++;
                }
            }
        }
        return [$base, $stats];
    }
}
