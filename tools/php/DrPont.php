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
        'goals'   => ['id'],
        'gifts'   => ['id'],
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
     * Total d'un objectif de l'effort de guerre, sans compter deux fois une ligne de la banque
     * lue par plusieurs membres (voir « Compter sans doublon » dans docs/PONT.md).
     *
     * @param array $goal  enregistrement `goals`
     * @param array $gifts enregistrements `gifts` (clé quelconque), sans pierres tombales
     * @param array $goals tous les objectifs actifs (pour savoir si un don hésite entre deux)
     */
    public static function goalTotal(array $goal, array $gifts, array $goals): int
    {
        $total = 0;
        foreach (self::uniqueGifts($gifts) as $g) {
            if (self::goalOfGift($g, $goals) === ($goal['id'] ?? null)) {
                $total += (int)$g['a'];
            }
        }
        return $total;
    }

    /** Les dons sans doublon : liste de ['c','k','a','it','at','g']. */
    public static function uniqueGifts(array $gifts, ?int $now = null): array
    {
        $now ??= time();
        $out = [];
        $bank = [];
        foreach ($gifts as $r) {
            if (!empty($r['del'])) {
                continue;
            }
            if (($r['src'] ?? '') === 'bank') {
                $key = ($r['c'] ?? '?') . '|' . ($r['k'] ?? '') . '|' . ($r['a'] ?? '') . '|' . ($r['it'] ?? '');
                $bank[$key][] = $r;
            } else {
                $out[] = $r;
            }
        }
        foreach ($bank as $list) {
            usort($list, fn($x, $y) => ((int)($x['at'] ?? 0)) <=> ((int)($y['at'] ?? 0)));
            $cluster = null;
            $flush = function () use (&$cluster, &$out) {
                if ($cluster === null) {
                    return;
                }
                $perReader = [];
                $explicit = null;
                foreach ($cluster['recs'] as $r) {
                    $who = $r['rd'] ?? ($r['by'] ?? '?');
                    $perReader[$who] = ($perReader[$who] ?? 0) + 1;
                    $explicit ??= $r['g'] ?? null;
                }
                $first = $cluster['recs'][0];
                $first['g'] = $explicit;
                for ($i = 0, $n = max($perReader); $i < $n; $i++) {
                    $out[] = $first;
                }
            };
            foreach ($list as $r) {
                $at = (int)($r['at'] ?? 0);
                if ($cluster !== null) {
                    $tolerance = ($now - $cluster['last']) > 25 * 86400 ? 3 * 86400 : 7200;
                    if ($at - $cluster['last'] <= $tolerance) {
                        $cluster['recs'][] = $r;
                        $cluster['last'] = $at;
                        continue;
                    }
                    $flush();
                }
                $cluster = ['recs' => [$r], 'last' => $at];
            }
            $flush();
        }
        return $out;
    }

    /** L'objectif d'un don : son `g` explicite, sinon l'unique objectif possible. */
    public static function goalOfGift(array $gift, array $goals): ?string
    {
        if (($gift['g'] ?? null) === '-') {
            return null;
        }
        if (isset($gift['g'])) {
            foreach ($goals as $g) {
                if (($g['id'] ?? null) === $gift['g']) {
                    return $g['id'];
                }
            }
        }
        $found = [];
        $at = (int)($gift['at'] ?? 0);
        foreach ($goals as $g) {
            if (!empty($g['del']) || ($g['k'] ?? '') !== ($gift['k'] ?? '')) {
                continue;
            }
            if (($g['k'] ?? '') === 'objet' && ($g['it'] ?? null) !== ($gift['it'] ?? null)) {
                continue;
            }
            if ($at >= (int)($g['from'] ?? 0) && $at <= (int)($g['to'] ?? PHP_INT_MAX)) {
                $found[] = $g['id'];
            }
        }
        return count($found) === 1 ? $found[0] : null;
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
