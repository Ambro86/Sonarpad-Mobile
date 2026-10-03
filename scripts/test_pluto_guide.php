<?php
declare(strict_types=1);
define('SONARPAD_PLUTO_GUIDE_LIBRARY_ONLY', true);
require __DIR__ . '/pluto_guide.php';

function check(bool $condition, string $message): void {
    if (!$condition) throw new RuntimeException($message);
}

$id = '661f8f4c307fa30008033ab5';
$fixture = tempnam(sys_get_temp_dir(), 'pluto-test-');
try {
    file_put_contents($fixture, "<?php\nconst CLIENT_TOKEN = 'test-only';\n" .
        "\$json = <<<'JSON'\n[{\"name\":\"Test\",\nJSON;\n" .
        "// Resolver comment between fragments\n\$json .= <<<'JSON'\n" .
        '"url":"https://sonarpad.com/api/pluto.php?id=' . $id . '"}]' . "\nJSON;\n");
    [$token, $ids] = pluto_resolver_config($fixture);
    check($token === 'test-only' && isset($ids[$id]), 'Read concatenated resolver nowdocs');
} finally {
    unlink($fixture);
}
$channels = [['id' => $id, 'name' => 'Canale', 'timelines' => [
    ['start' => '2026-10-03T16:00:00Z', 'stop' => '2026-10-03T17:00:00Z',
        'title' => '', 'episode' => ['name' => 'Episodio', 'series' => ['description' => 'Descrizione']]],
    ['start' => '2026-10-03T16:30:00Z', 'stop' => '2026-10-03T17:00:00Z', 'title' => 'no info available'],
    ['start' => 'invalid', 'stop' => 'invalid', 'title' => 'Invalid'],
]], ['id' => 'excluded', 'timelines' => []]];
$normalized = pluto_normalize($channels, [$id => true]);
check(count($normalized) === 1 && count($normalized[$id]) === 2, 'Filtering');
check($normalized[$id][0]['hour'] === '18:00', 'Europe/Rome summer offset');
check($normalized[$id][0]['description'] === 'Descrizione', 'Description fallback');
check(pluto_current($normalized[$id], strtotime('2026-10-03T16:45:00Z'))['title'] === 'Episodio', 'Prefer real data over overlapping filler');
check(pluto_current([$normalized[$id][1]], strtotime('2026-10-03T16:45:00Z'))['title'] === 'no info available', 'Keep sole filler');
check(pluto_current($normalized[$id], strtotime('2026-10-03T15:00:00Z')) === null, 'Never show future program');
check(pluto_current($normalized[$id], strtotime('2026-10-04T00:00:00Z')) === null, 'Expire stale fallback');
check(pluto_current($normalized[$id], strtotime('2026-10-03T18:00:00Z')) !== null, 'Recent fallback');
$channels[0]['timelines'][0]['start'] = '2026-12-03T16:00:00Z';
$channels[0]['timelines'][0]['stop'] = '2026-12-03T17:00:00Z';
$winter = pluto_normalize([$channels[0]], [$id => true]);
check($winter[$id][1]['hour'] === '17:00', 'Europe/Rome winter offset');
echo "Pluto PHP tests passed\n";
