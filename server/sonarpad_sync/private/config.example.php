<?php
declare(strict_types=1);

return [
    'database_path' => __DIR__ . '/../data/sync.sqlite',
    'require_https' => true,
    'max_devices' => 10,
    'code_lifetime_seconds' => 600,
    'log_path' => __DIR__ . '/../data/sync.log',
    'log_max_bytes' => 262144,
    'log_archives' => 3,
    'log_max_age_days' => 5,
];
