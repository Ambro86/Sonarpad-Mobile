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
check(pluto_current([$normalized[$id][1]], strtotime('2026-10-03T16:45:00Z')) === null, 'No now-playing label for a sole placeholder');
check(pluto_current($normalized[$id], strtotime('2026-10-03T15:00:00Z')) === null, 'Never show future program');
check(pluto_current($normalized[$id], strtotime('2026-10-04T00:00:00Z')) === null, 'Expire stale fallback');
check(pluto_current($normalized[$id], strtotime('2026-10-03T18:00:00Z')) === null, 'Placeholder blocks stale fallback');
check(pluto_current([$normalized[$id][0]], strtotime('2026-10-03T18:00:00Z')) !== null, 'Recent real fallback');
check(pluto_current([
    ['title' => 'Programma precedente', 'startTime' => 100, 'endTime' => 200],
    ['title' => 'Programma non specificato', 'startTime' => 200, 'endTime' => 300],
], 250) === null, 'Do not claim a previous show is still on air during an unknown slot');
$channels[0]['timelines'][0]['start'] = '2026-12-03T16:00:00Z';
$channels[0]['timelines'][0]['stop'] = '2026-12-03T17:00:00Z';
$winter = pluto_normalize([$channels[0]], [$id => true]);
check($winter[$id][1]['hour'] === '17:00', 'Europe/Rome winter offset');

function title_case(string $channel, string $title, string $episode, string $series, string $expected, string $type = 'tv', int $season = 2, int $number = 9): void {
    $actual = pluto_program_title(['title' => $title, 'episode' => ['name' => $episode,
        'season' => $season, 'number' => $number, 'series' => ['name' => $series, 'type' => $type]]], $channel);
    check($actual === $expected, $channel . ': expected ' . $expected . ', got ' . $actual);
}
title_case('Nina', 'Nina', 'Sul ring', 'Nina', 'Sul ring');
title_case('Le sorelle McLeod', 'Le Sorelle McLeod: Nei boschi', 'Nei boschi', 'Le Sorelle McLeod', 'Nei boschi');
title_case('Pluto TV Serie', 'Le Sorelle McLeod: Nei boschi', 'Nei boschi', 'Le Sorelle McLeod', 'Le Sorelle McLeod: Nei boschi');
title_case('Pluto TV Paranormal', 'Most Haunted', 'Wentworth Woodhouse', 'Most Haunted', 'Most Haunted: Wentworth Woodhouse');
title_case('Cin Cin', 'Cheers', 'Che c’è Doc?', 'Cheers', 'Che c’è Doc?');
title_case('Star Trek: Voyager', 'Star Trek: Voyager: Il segreto di Neelix', 'Il segreto di Neelix', 'Star Trek: Voyager', 'Il segreto di Neelix');
title_case('Nina', 'Nina: Sul ring', '', 'Nina', 'Sul ring');
title_case('Pluto TV Alieni', 'Ape vs Monster', 'Ape vs Monster', 'Ape vs Monster', 'Ape vs Monster', 'film');
title_case('Pluto TV Horror', 'The Ghost of Sierra de Cobre', 'Il Fantasma della Sierra de Cobre', 'The Ghost of Sierra de Cobre', 'The Ghost of Sierra de Cobre', 'film');
title_case('Inter 24/7', 'Serie A | Roma - Inter | 2026/2027', 'Serie A', 'Serie A | Roma - Inter | 2026/2027', 'Serie A | Roma - Inter | 2026/2027', 'live');
title_case('SpongeBob', 'SpongeBob', 'SpongeBob', 'SpongeBob', 'Programma non specificato', 'live', 1, 1);
title_case('Pluto TV Notti di Passione', 'Pluto TV Notti di Passione', 'Pluto TV Notti di Passione', 'Pluto TV Notti di Passione', 'Programma non specificato', 'tv', 1, 2);
title_case("That's 70s", 'That’s 70s', 'That’s 70s', 'That’s 70s', 'Programma non specificato', 'live');
title_case('Barbie & Friends', 'Monster High', 'Monster High', 'Monster High', 'Monster High: Stagione 1, episodio 21', 'tv', 1, 21);
title_case('H2O & Friends', 'Wolfblood', 'S02 E01', 'Wolfblood', 'Wolfblood: Stagione 2, episodio 1', 'live');
title_case('FailArmy', 'Best Fails of the Month', 'Best Fails of the Month Ep. 9.3', 'Best Fails of the Month', 'Best Fails of the Month Ep. 9.3', 'live');
title_case('Pluto TV Serie', 'Nina: Finale speciale', 'Altro titolo', 'Nina', 'Nina: Finale speciale');
title_case('Geordie Shore', 'Torna alle 22:00', 'Torna alle 22:00', 'Torna alle 22:00', 'Torna alle 22:00', 'tv', 1, 23);
title_case('16 Anni e Incinta', '16 Anni e Incinta Italia: Carmen pt.1.', 'Carmen pt.1.', '16 Anni e Incinta Italia', 'Carmen pt.1.');
title_case('Sanctuary', 'Sanctuary: La Citta Sotterranea', 'La Citta Sotterranea', 'Sanctuary', 'La Città Sotterranea');
title_case('Pluto TV True Crime', 'Forensic Files: Nella Busta', 'Nella Busta', 'Forensic Files', 'Forensic Files: Nella Busta');
title_case('Forensic Files', 'Forensic Files: Ago in un Pagliaio', 'Ago in un Pagliaio', 'Forensic Files', 'Ago in un Pagliaio');
echo "Pluto PHP tests passed\n";
