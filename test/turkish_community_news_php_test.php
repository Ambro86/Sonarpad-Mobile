<?php

declare(strict_types=1);

// Run with: php test/turkish_community_news_php_test.php
// No HTTP requests are sent. Endpoint definitions are loaded in isolated
// namespaces; GET filtering reads a temporary fixture, never production data.

$checks = 0;
function expect_same(mixed $actual, mixed $expected, string $description): void
{
    global $checks;
    if ($actual !== $expected) {
        throw new RuntimeException($description . ': ' . var_export($actual, true));
    }
    $checks++;
}

function php_body(string $source): string
{
    $source = preg_replace('/^<\?php\s*/', '', $source);
    return str_replace('declare(strict_types=1);', '', (string)$source);
}

$project = dirname(__DIR__);
$addSource = file_get_contents($project . '/server/add_community_news_source.php');
$getSource = file_get_contents($project . '/server/get_community_news_sources.php');
if ($addSource === false || $getSource === false) {
    throw new RuntimeException('Cannot read community endpoints.');
}
$addEntry = strpos($addSource, "\nif (\$_SERVER['REQUEST_METHOD'] !== 'POST') {");
$getEntry = strpos($getSource, "\n\$sources = load_json_file(");
if ($addEntry === false || $getEntry === false) {
    throw new RuntimeException('Cannot locate endpoint entry points.');
}
eval('namespace AddEndpoint; ' . php_body(substr($addSource, 0, $addEntry)));
eval('namespace GetEndpoint; ' . php_body(substr($getSource, 0, $getEntry)));

$expectedLanguages = [
    'italian', 'english', 'french', 'spanish', 'portuguese',
    'portuguese_brazil', 'polish', 'czech', 'german',
    'chinese_simplified', 'ukrainian', 'romanian', 'turkish',
];
expect_same(array_keys(AddEndpoint\ALLOWED_LANGUAGES), $expectedLanguages,
    'The server accepts every language offered by NewsLanguage');
expect_same(AddEndpoint\ALLOWED_LANGUAGES['turkish'], 'Türkçe',
    'The stored Turkish label is native');
expect_same(AddEndpoint\LANGUAGE_ALIASES, GetEndpoint\LANGUAGE_ALIASES,
    'Add and browse share the same language aliases');

foreach ($expectedLanguages as $language) {
    expect_same(AddEndpoint\normalize_language($language), $language,
        'Canonical add language round trip: ' . $language);
    expect_same(GetEndpoint\normalize_language($language), $language,
        'Canonical browse language round trip: ' . $language);
}
foreach (['tr', 'TR', 'tr-TR', 'tr_TR', 'turkish', 'TURKISH', 'Türkçe', 'TÜRKÇE', 'türkçe', 'turkce', 'turco'] as $alias) {
    expect_same(AddEndpoint\normalize_language($alias), 'turkish',
        'Turkish add alias: ' . $alias);
    expect_same(GetEndpoint\normalize_language($alias), 'turkish',
        'Turkish browse alias: ' . $alias);
}
foreach ([
    'pt_BR' => 'portuguese_brazil',
    'pt-BR' => 'portuguese_brazil',
    'portuguese-brazil' => 'portuguese_brazil',
    'zh_CN' => 'chinese_simplified',
    'zh-CN' => 'chinese_simplified',
    'chinese-simplified' => 'chinese_simplified',
    'de-DE' => 'german',
    'uk-UA' => 'ukrainian',
    'pt' => 'portuguese',
    'română' => 'romanian',
    'italiano' => 'italian',
] as $alias => $language) {
    expect_same(AddEndpoint\normalize_language($alias), $language,
        'Regional or legacy add alias: ' . $alias);
    expect_same(GetEndpoint\normalize_language($alias), $language,
        'Regional or legacy browse alias: ' . $alias);
}
expect_same(AddEndpoint\normalize_language('unsupported'), null,
    'Unknown add languages are rejected');

$_GET = [];
$_SERVER['HTTP_ACCEPT_LANGUAGE'] = 'en-US,en;q=0.9';
foreach (['tr', 'tr-TR', 'tr_TR'] as $locale) {
    expect_same(AddEndpoint\get_ui_language(['ui_language' => $locale]), 'tr',
        'Explicit Turkish UI locale overrides the request header');
}
$_SERVER['HTTP_ACCEPT_LANGUAGE'] = 'tr;q=0.9,en;q=0.8';
expect_same(AddEndpoint\get_ui_language([]), 'tr',
    'Turkish Accept-Language quality values are handled');
expect_same(AddEndpoint\get_ui_language(['ui_language' => 'en']), 'en',
    'Explicit English UI remains English for a Turkish source');
expect_same(AddEndpoint\normalize_ui_language('de-DE'), 'it',
    'Previously unsupported server UI languages retain their legacy fallback');

foreach (AddEndpoint\MESSAGES as $code => $translations) {
    expect_same(isset($translations['tr']) && $translations['tr'] !== '', true,
        'Turkish server message exists: ' . $code);
    preg_match_all('/\{[a-zA-Z_][a-zA-Z0-9_]*\}/', $translations['en'], $enParameters);
    preg_match_all('/\{[a-zA-Z_][a-zA-Z0-9_]*\}/', $translations['tr'], $trParameters);
    sort($enParameters[0]);
    sort($trParameters[0]);
    expect_same($trParameters[0], $enParameters[0],
        'Turkish placeholders match English: ' . $code);
}
expect_same(AddEndpoint\translate_message('SOURCE_ADDED', [], ['ui_language' => 'tr_TR']),
    'Haber kaynağı Sonarpad topluluğuna başarıyla eklendi.',
    'Successful submissions return Turkish');
expect_same(AddEndpoint\translate_message('FEED_HTTP_ERROR', ['code' => 503], ['ui_language' => 'tr']),
    'Adres, HTTP 503 durum kodunu döndürdü.',
    'HTTP errors interpolate their status in Turkish');
expect_same(AddEndpoint\translate_message('SOURCE_ADDED', [], ['ui_language' => 'en']),
    'News source added successfully to the Sonarpad community.',
    'Existing English responses are preserved');
expect_same(AddEndpoint\google_news_parameters('turkish'), ['tr', 'TR', 'TR:tr'],
    'Website discovery uses the Turkish Google News edition');
$googleUrl = AddEndpoint\google_news_site_feed('www.example.test', 'turkish');
parse_str((string)parse_url($googleUrl, PHP_URL_QUERY), $googleQuery);
expect_same($googleQuery, ['q' => 'site:example.test', 'hl' => 'tr', 'gl' => 'TR', 'ceid' => 'TR:tr'],
    'The site query and edition parameters survive URL encoding');

$temporaryRoot = sys_get_temp_dir() . '/sonarpad-community-test-' . bin2hex(random_bytes(6));
mkdir($temporaryRoot . '/server', 0700, true);
mkdir($temporaryRoot . '/data_private', 0700, true);
$fixtureFile = $temporaryRoot . '/data_private/community_news_sources.json';
$fixture = [
    ['name' => 'A Turkish', 'url' => 'https://example.test/a.rss', 'language' => 'turkish'],
    ['name' => 'B Turkish', 'url' => 'https://example.test/b.rss', 'language' => 'tr_TR'],
    ['name' => 'C Turkish', 'url' => 'https://example.test/c.rss', 'language' => 'TÜRKÇE'],
    ['name' => 'English', 'url' => 'https://example.test/en.rss', 'language' => 'english'],
    ['name' => 'Brazil', 'url' => 'https://example.test/br.rss', 'language' => 'pt_BR'],
    ['name' => 'Portugal', 'url' => 'https://example.test/pt.rss', 'language' => 'portuguese'],
    ['name' => 'Chinese', 'url' => 'https://example.test/zh.rss', 'language' => 'chinese_simplified'],
];
file_put_contents($fixtureFile, json_encode($fixture, JSON_UNESCAPED_UNICODE));
$storedBefore = file_get_contents($fixtureFile);

try {
    $caseNumber = 0;
    foreach ([
        'tr_TR' => [['A Turkish', 'B Turkish', 'C Turkish'], 'turkish'],
        'turkish' => [['A Turkish', 'B Turkish', 'C Turkish'], 'turkish'],
        'TÜRKÇE' => [['A Turkish', 'B Turkish', 'C Turkish'], 'turkish'],
        'pt_BR' => [['Brazil'], 'portuguese_brazil'],
        'portuguese' => [['Portugal'], 'portuguese'],
        'zh-CN' => [['Chinese'], 'chinese_simplified'],
    ] as $queryLanguage => [$expectedNames, $canonicalLanguage]) {
        $_GET = ['language' => $queryLanguage];
        $relocatedSource = str_replace('__DIR__', var_export($temporaryRoot . '/server', true), php_body($getSource));
        ob_start();
        eval('namespace BrowseCase' . $caseNumber++ . '; ' . $relocatedSource);
        $rows = json_decode((string)ob_get_clean(), true, 512, JSON_THROW_ON_ERROR);
        expect_same(array_column($rows, 'name'), $expectedNames,
            'Browse filters stored aliases correctly: ' . $queryLanguage);
        expect_same(array_unique(array_column($rows, 'language')), [$canonicalLanguage],
            'Browse returns canonical language keys: ' . $queryLanguage);
    }
    expect_same(file_get_contents($fixtureFile), $storedBefore,
        'Browsing and normalizing aliases never rewrite stored community data');
} finally {
    unlink($fixtureFile);
    rmdir($temporaryRoot . '/data_private');
    rmdir($temporaryRoot . '/server');
    rmdir($temporaryRoot);
}

echo 'PASS: ' . $checks . " community PHP checks; no network requests or production writes.\n";
