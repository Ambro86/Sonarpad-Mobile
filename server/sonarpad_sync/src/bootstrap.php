<?php
declare(strict_types=1);

ini_set('display_errors', '0');
error_reporting(E_ALL);

class ApiError extends RuntimeException {
    public function __construct(public int $httpStatus, public string $errorName) {
        parent::__construct($errorName);
    }
}

function api_fail(int $status, string $name): never { throw new ApiError($status, $name); }

function sync_config(): array {
    $path = __DIR__ . '/../private/config.php';
    return array_replace(require __DIR__ . '/../private/config.example.php',
        is_file($path) ? require $path : []);
}

function db(): PDO {
    static $pdo;
    if ($pdo instanceof PDO) return $pdo;
    $path = sync_config()['database_path'];
    if (!is_dir(dirname($path)) && !mkdir(dirname($path), 0700, true)) {
        throw new RuntimeException('Cannot create database directory');
    }
    $pdo = new PDO('sqlite:' . $path, null, null, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    $pdo->exec('PRAGMA foreign_keys=ON');
    $pdo->exec('PRAGMA journal_mode=WAL');
    $pdo->exec('PRAGMA busy_timeout=5000');
    return $pdo;
}

function write_transaction(PDO $pdo, callable $action): mixed {
    $pdo->exec('BEGIN IMMEDIATE');
    try {
        $result = $action();
        $pdo->exec('COMMIT');
        return $result;
    } catch (Throwable $e) {
        $pdo->exec('ROLLBACK');
        throw $e;
    }
}

function json_response(int $status, array $body): never {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    header('X-Content-Type-Options: nosniff');
    header('Referrer-Policy: no-referrer');
    echo json_encode($body, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function read_json_body(): array {
    $raw = file_get_contents('php://input', false, null, 0, 2097153);
    if ($raw === false || strlen($raw) > 2097152) api_fail(413, 'request_too_large');
    try { $body = json_decode($raw, true, 32, JSON_THROW_ON_ERROR); }
    catch (JsonException) { api_fail(400, 'invalid_json'); }
    if (!is_array($body) || !str_starts_with(ltrim($raw), '{')) api_fail(400, 'invalid_json');
    return $body;
}

function bearer_token(): string {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($header === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $key => $value) {
            if (strcasecmp($key, 'Authorization') === 0) $header = $value;
        }
    }
    if (!preg_match('/^Bearer ([a-f0-9]{64})$/D', $header, $match)) api_fail(401, 'unauthorized');
    return $match[1];
}
