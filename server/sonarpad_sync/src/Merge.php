<?php
declare(strict_types=1);

const SYNC_COLLECTIONS = ['radio', 'news_sources', 'news_folders', 'news_articles', 'tv', 'podcasts', 'sonartube', 'preferences'];

function validate_preferences(array $items): void {
    if (count($items) > 128 || strlen(json_encode($items, JSON_THROW_ON_ERROR)) > 32768) api_fail(413, 'preferences_limit');
    foreach ($items as $item) {
        if (!preg_match('/^[a-z][a-z0-9_.]{1,79}$/D', $item['id'] ?? '') ||
            array_keys($item['data']) !== ['value'] ||
            strlen(json_encode($item['data'], JSON_THROW_ON_ERROR)) > 2048) api_fail(400, 'invalid_preference');
    }
}

function validate_state(mixed $state): array {
    if (!is_array($state)) api_fail(400, 'invalid_state');
    foreach ($state as $name => $items) {
        if (!in_array($name, SYNC_COLLECTIONS, true) || !is_array($items) ||
            !array_is_list($items) || count($items) > 5000) api_fail(400, 'invalid_collection');
        $ids = [];
        foreach ($items as $item) {
            if (!is_array($item) || !is_string($item['id'] ?? null) ||
                strlen($item['id']) < 1 || strlen($item['id']) > 2048 ||
                !is_array($item['data'] ?? null) || array_is_list($item['data']) ||
                strlen(json_encode($item['data'], JSON_THROW_ON_ERROR)) > 65536 ||
                isset($ids[$item['id']])) api_fail(400, 'invalid_item');
            $ids[$item['id']] = true;
        }
        if ($name === 'preferences') validate_preferences($items);
    }
    return $state;
}

/** Apply only local changes since baseline to the latest remote state.
 * Omitted collections stay untouched; concurrent deletion wins over editing.
 */
function merge_state(array $remote, array $base, array $local): array {
    foreach ($local as $name => $items) {
        $before = array_column($base[$name] ?? [], null, 'id');
        $after = array_column($items, null, 'id');
        $current = array_column($remote[$name] ?? [], null, 'id');
        foreach ($before as $id => $_) {
            if (!isset($after[$id])) unset($current[$id]);
        }
        foreach ($after as $id => $item) {
            if (isset($before[$id])) {
                if (!isset($current[$id])) continue;
                foreach ($item['data'] as $key => $value) {
                    if (!array_key_exists($key, $before[$id]['data']) || $before[$id]['data'][$key] !== $value) {
                        $current[$id]['data'][$key] = $value;
                    }
                }
                foreach ($before[$id]['data'] as $key => $_) {
                    if (!array_key_exists($key, $item['data'])) unset($current[$id]['data'][$key]);
                }
            } else {
                // A newly connected device must not overwrite an existing
                // preference with its installation defaults on first sync.
                if ($name === 'preferences' && isset($current[$id])) continue;
                $current[$id] = ['id' => $item['id'], 'data' => array_replace($current[$id]['data'] ?? [], $item['data'])];
            }
        }
        if (array_keys($before) !== array_keys($after)) {
            $ordered = [];
            foreach ($after as $id => $_) {
                if (isset($current[$id])) { $ordered[$id] = $current[$id]; unset($current[$id]); }
            }
            $current = $ordered + $current;
        }
        $remote[$name] = array_values($current);
    }
    if (strlen(json_encode($remote, JSON_THROW_ON_ERROR)) > 4194304) api_fail(413, 'storage_limit');
    foreach ($remote as $items) if (count($items) > 5000) api_fail(413, 'storage_limit');
    if (isset($remote['preferences'])) validate_preferences($remote['preferences']);
    return $remote;
}

/** Missing collections mean unsupported scope, never permission to delete. */
function removed_collection_items(array $before, array $after): array {
    $removed = [];
    foreach ($after as $name => $rows) {
        $ids = array_column($rows, null, 'id');
        foreach ($before[$name] ?? [] as $row) {
            if (!isset($ids[$row['id']])) $removed[$name][] = $row['id'];
        }
    }
    return $removed;
}
