<?php
declare(strict_types=1);
// Run: php tool/test_youtube_channel_collections.php PATH_TO_RESOLVER
function http_post_json_web(string $url, array $payload): array {
    $GLOBALS['sent'][] = $payload;
    if ($GLOBALS['queue'] === []) throw new RuntimeException('Unexpected request');
    return ['ok' => true, 'body' => json_encode(array_shift($GLOBALS['queue']))];
}
function http_post_json(string $url, array $payload, array $headers = []): array {
    return http_post_json_web($url, $payload);
}
$source = file_get_contents($argv[1]);
preg_match("/const SONARPAD_YOUTUBE_CLIENT_TOKEN = '([^']+)'/", $source, $match);
$_SERVER['HTTP_X_SONARPAD_ROUTE_TOKEN'] = $match[1];
$library = substr(explode('// Run', $source, 2)[0], 5);
eval(str_replace(['function http_post_json_web(', 'function http_post_json('],
    ['function unused_live_http_post_json_web(', 'function unused_live_http_post_json('], $library));
function check(bool $condition, string $message): void {
    if (!$condition) throw new RuntimeException($message);
    echo "PASS $message\n";
}
$id = 'UCabcdefghijklmnopqrstuv';
foreach (['course', 'podcast'] as $category) {
    $items = [];
    foreach (['COURSE', 'PODCAST', 'PLAYLIST'] as $kind) {
        $items[] = ['lockupViewModel' => [
            'contentType' => 'LOCKUP_CONTENT_TYPE_' . $kind, 'contentId' => 'PL' . $kind,
            'metadata' => ['lockupMetadataViewModel' => ['title' => ['content' => 'Course podcast']]],
        ]];
    }
    $GLOBALS['queue'] = [['contents' => $items]]; $GLOBALS['sent'] = [];
    $result = youtube_search('science', '', 1, $category, false, 'best', 'audio');
    check(count($result['items']) === 1 && $result['items'][0]['collection_type'] === $category,
        "$category search filters by actual YouTube type");
    check($GLOBALS['sent'][0]['params'] === 'EgIQAw==', "$category search requests collections");
    $GLOBALS['queue'] = [['contents' => $items]]; $GLOBALS['sent'] = [];
    $result = youtube_search('science', 'next-token', 2, $category, false, 'best', 'audio');
    check(count($result['items']) === 1 && $GLOBALS['sent'][0]['continuation'] === 'next-token',
        "$category search continuation preserves type");
}
$courseVideo = ['lockupViewModel' => [
    'contentType' => 'LOCKUP_CONTENT_TYPE_VIDEO', 'contentId' => 'abcdefghijk',
    'metadata' => ['lockupMetadataViewModel' => [
        'title' => ['content' => 'Lesson'],
        'image' => ['decoratedAvatarViewModel' => []],
        'metadata' => ['contentMetadataViewModel' => ['metadataRows' => [[
            'metadataParts' => [['text' => ['content' => '154K views']], ['text' => ['content' => '6 years ago']]],
        ]]]],
    ]],
]];
$parsed = extract_search_items($courseVideo)[0];
check($parsed['views'] === '154K views' && $parsed['channel'] === null && $parsed['published'] === '6 years ago', 'course video single metadata row retains views');
$item = ['gridPlaylistRenderer' => [
    'playlistId' => 'PLcollection001', 'title' => ['simpleText' => 'Collection'],
    'videoCount' => '12',
]];
foreach (['courses', 'podcasts'] as $tab) {
    $endpoint = ['commandMetadata' => ['webCommandMetadata' => ['url' => '/@channel/' . $tab]],
        'browseEndpoint' => ['params' => 'server%3D']];
    $first = ['metadata' => ['channelMetadataRenderer' => ['title' => 'Channel', 'externalId' => $id]],
        'contents' => ['tabs' => [['tabRenderer' => [
            'endpoint' => $endpoint, 'selected' => true, 'content' => [$item],
        ]]]]];
    $discovery = $first;
    $discovery['contents']['tabs'][0]['tabRenderer']['selected'] = false;
    $GLOBALS['queue'] = [$discovery, $first]; $GLOBALS['sent'] = [];
    $result = youtube_browse($id, 'channel_' . $tab, '', 1, '');
    check($result['ok'] && $result['kind'] === 'channel_' . $tab && $result['count'] === 1, "$tab discovery and playlist parsing");
    check(!isset($GLOBALS['sent'][0]['params']) && $GLOBALS['sent'][1]['params'] === 'server=', "$tab follows real endpoint");
    $GLOBALS['queue'] = [['onResponseReceivedActions' => [['appendContinuationItemsAction' => [
        'targetId' => 'random-uuid', 'continuationItems' => [$item],
    ]]]]];
    $result = youtube_browse($id, 'channel_' . $tab, 'next-token', 2, 'Channel');
    check($result['ok'] && $result['count'] === 1 && $result['page'] === 2, "$tab modern continuation");
    $first['contents']['tabs'][0]['tabRenderer']['endpoint']['commandMetadata']['webCommandMetadata']['url'] = '/@channel/featured';
    $GLOBALS['queue'] = [$first];
    $result = youtube_browse($id, 'channel_' . $tab, '', 1, '');
    check($result['ok'] && $result['count'] === 0, "$tab absent never leaks home playlists");
    $GLOBALS['queue'] = [['ok' => false, 'error' => ['message' => 'Unavailable']]];
    $result = youtube_browse($id, 'channel_' . $tab, '', 1, '');
    check(!$result['ok'], "$tab upstream errors are not empty collections");
}
