<?php
// php test/news_feed_discovery_php_test.php [path-to-add_community_news_source.php]
$path = $argv[1] ?? dirname(__DIR__) . '/server/add_community_news_source.php';
$source = file_get_contents($path);
$end = strpos($source, "\nif (\$_SERVER['REQUEST_METHOD'] !== 'POST') {");
if ($end === false) throw new RuntimeException('Missing endpoint boundary');
$definitions = substr($source, 0, $end);
$definitions = preg_replace('/^<\?php\s*/', '', $definitions);
$definitions = str_replace('declare(strict_types=1);', '', $definitions);
$definitions = str_replace('function fetch_url_sample(', 'function unused_fetch_url_sample(', $definitions);
eval($definitions);
$requests = [];
function fetch_url_sample(string $url, string $accept, int $limit, array $input): array {
    global $requests;
    $requests[] = $url;
    $body = parse_url($url, PHP_URL_HOST) === 'example.org'
        ? '<rss><channel><item><title>Old</title><pubDate>Mon, 19 Oct 2015 12:00:00 +0300</pubDate></item></channel></rss>'
        : '<rss><channel><title>News</title><item><title>Current</title><pubDate>' . gmdate(DATE_RSS) . '</pubDate></item></channel></rss>';
    if ($url === 'https://example.org/') $body = '<html><link rel="alternate" type="application/rss+xml" href="/old.xml"></html>';
    return ['ok'=>true, 'body'=>$body, 'effective_url'=>$url, 'content_type'=>'application/xml'];
}
$count = 0;
function check($condition) { global $count; if (!$condition) throw new RuntimeException('Failed check '.($count+1)); $count++; }
$now = strtotime('2026-10-20T00:00:00Z');
check(!feed_sample_is_usable('<html>RSS service</html>', $now));
check(!feed_sample_is_usable('<rss><channel/></rss>', $now));
check(!feed_sample_is_usable('<rss><channel><item><pubDate>Mon, 19 Oct 2015 12:00:00 +0300</pubDate></item></channel></rss>', $now));
check(feed_sample_is_usable('<rss><channel><item><pubDate>Sal, 20 Eki 2026 02:30:00 +0300</pubDate></item></channel></rss>', $now));
check(feed_sample_is_usable('<feed><entry><published>2026-10-19T20:00:00Z</published></entry></feed>', $now));
check(feed_sample_is_usable('<rss><channel><item><title>Undated</title></item></channel></rss>', $now));
check(preferred_news_feed('https://www.turkiyegazetesi.com.tr/rss/son-dakika-haberleri') === 'https://www.turkiyegazetesi.com.tr/rss');
check(preferred_news_feed('https://www.tgrthaber.com/rss/son-dakika') === 'https://www.tgrthaber.com/rss/manset');
check(preferred_news_feed('https://www.aa.com.tr/tr') === 'https://www.aa.com.tr/tr/rss/default?cat=guncel');
check(preferred_news_feed('https://www.turkiyegazetesi.com.tr/rss/spor') === null);
$result = resolve_feed_or_site('https://www.turkiyegazetesi.com.tr', 'turkish', []);
check($result['url'] === 'https://www.turkiyegazetesi.com.tr/rss');
check(count($requests) === 1);
$result = resolve_feed_or_site('https://example.org/', 'turkish', []);
check($result['resolved_kind'] === 'google_news_site');
check(str_contains($result['url'], 'news.google.com/rss/search'));
$result = resolve_feed_or_site('https://example.org/old.xml', 'turkish', []);
check($result['url'] === 'https://example.org/old.xml'); // Explicit archives are preserved.
echo "$count checks passed\n";
