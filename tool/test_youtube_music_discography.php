<?php
declare(strict_types=1);
// php tool/test_youtube_music_discography.php PATH_TO_MUSIC_RESOLVER
function ytm_post(string $url, array $payload, array $headers): array {
    $GLOBALS['sent'][] = [$payload, $headers];
    if (!$GLOBALS['queue']) throw new RuntimeException('Unexpected request');
    return ['ok' => true, 'body' => json_encode(array_shift($GLOBALS['queue']))];
}
$source = file_get_contents($argv[1]);
preg_match("/const SONARPAD_YOUTUBE_CLIENT_TOKEN = '([^']+)'/", $source, $match);
$_SERVER['HTTP_X_SONARPAD_ROUTE_TOKEN'] = $match[1];
eval(str_replace('function ytm_post(', 'function unused_ytm_post(', substr(explode('// Input', $source, 2)[0], 5)));
function check(bool $ok, string $label): void {
    if (!$ok) throw new RuntimeException($label);
    echo "PASS $label\n";
}
$album = ['musicTwoRowItemRenderer' => [
    'title' => ['runs' => [['text' => 'American Beauty']]],
    'navigationEndpoint' => ['browseEndpoint' => ['browseId' => 'MPREalbum']],
]];
$raw = ['responseContext' => ['visitorData' => 'visitor-example'],
    'contents' => ['gridRenderer' => ['items' => [$album],
        'continuations' => [['nextContinuationData' => ['continuation' => 'native%3D']]]]]];
foreach (['search', 'browse'] as $mode) {
    $GLOBALS['queue'] = [$raw, $raw]; $GLOBALS['sent'] = [];
    $first = $mode === 'search' ? ytm_search('Grateful Dead', '', 1, 'album', false, 'audio')
        : ytm_browse('MPADartist', '', 1, 'albums');
    check($first['ok'] && str_starts_with($first['next_token'], 'sonarpad-ytm:'), "$mode wraps visitor context");
    $second = $mode === 'search' ? ytm_search('Grateful Dead', $first['next_token'], 2, 'album', false, 'audio')
        : ytm_browse('MPADartist', $first['next_token'], 2, 'albums');
    [$payload, $headers] = $GLOBALS['sent'][1];
    check($payload['continuation'] === 'native=', "$mode decodes native continuation");
    check($payload['context']['client']['visitorData'] === 'visitor-example'
        && in_array('X-Goog-Visitor-Id: visitor-example', $headers, true), "$mode preserves visitor in body and headers");
    if ($mode === 'browse') {
        check($GLOBALS['sent'][0][0]['params'] === 'albums', 'discography parameters sent');
        check(count($first['sections'][0]['items']) === 1, 'grid albums parsed');
    }
}
$GLOBALS['queue'] = [['continuationContents' => ['gridContinuation' => ['items' => [$album]]]]];
$result = ytm_browse('MPADartist', '', 1);
check(count($result['sections'][0]['items']) === 1, 'continuation grid parsed');
$shelf = ['header' => ['musicCarouselShelfBasicHeaderRenderer' => [
    'title' => ['runs' => [['text' => 'Albums']]],
    'moreContentButton' => ['buttonRenderer' => ['navigationEndpoint' => ['browseEndpoint' => [
        'browseId' => 'MPADartist', 'params' => 'albums',
    ]]]],
]], 'contents' => [$album]];
$items = ytm_parse_shelf($shelf)['items'];
check($items[0]['kind'] === 'collection' && $items[0]['browse_params'] === 'albums' && count($items) === 2,
    'artist includes full discography link and preview albums');
check(!ytm_browse('MPADartist', 'sonarpad-ytm:invalid', 2)['ok'], 'malformed continuation rejected');
