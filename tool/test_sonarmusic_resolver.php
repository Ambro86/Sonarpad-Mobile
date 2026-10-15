<?php
// Run against the deployment file without executing its HTTP entry point or
// loading credentials: php tool/test_sonarmusic_resolver.php /path/to/resolver.php
$source = file_get_contents($argv[1]);
$tokens = token_get_all($source);
for ($i = 0; $i < count($tokens); $i++) {
    if (!is_array($tokens[$i]) || $tokens[$i][0] !== T_FUNCTION) { continue; }
    $function = '';
    $depth = 0;
    $started = false;
    do {
        $token = $tokens[$i];
        $function .= is_array($token) ? $token[1] : $token;
        if ($token === '{') { $started = true; $depth++; }
        if ($token === '}') { $depth--; }
        $i++;
    } while ($i < count($tokens) && (!$started || $depth > 0));
    $i--;
    eval($function);
}
function check($actual, $expected): void {
    if ($actual !== $expected) { throw new RuntimeException('Resolver assertion failed'); }
}
$fixture = json_decode(file_get_contents(__DIR__ . '/../test/fixtures/sonarmusic/fivelandia_11.json'), true);
$shelf = ytm_collection_shelf($fixture);
$items = ytm_parse_shelf($shelf)['items'];
check(count($items), 12);
check($items[0]['title'], 'Tazmania');
check(ytm_next_token($shelf), null);
foreach (['musicShelfRenderer', 'musicPlaylistShelfRenderer', 'musicShelfContinuation', 'musicPlaylistShelfContinuation', 'appendContinuationItemsAction'] as $key) {
    $data = [
        'recommendations' => ['musicCarouselShelfRenderer' => [
            'musicShelfRenderer' => ['continuations' => [['nextContinuationData' => ['continuation' => 'wrong']]]],
        ]],
        'tracks' => [$key => ['contents' => [], 'continuations' => [['nextContinuationData' => ['continuation' => 'correct']]]]],
    ];
    check(ytm_next_token(ytm_collection_shelf($data)), 'correct');
}
check(ytm_next_token(['continuationItemRenderer' => ['continuationEndpoint' => ['continuationCommand' => ['token' => 'command-next']]]]), 'command-next');
check(ytm_collection_shelf(['musicCarouselShelfRenderer' => ['contents' => []]]), null);
echo "Album tracks, recommendation exclusion and pagination: passed\n";
