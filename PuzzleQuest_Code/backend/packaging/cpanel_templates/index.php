<?php

declare(strict_types=1);

// Fixed-root cPanel layout: this file is public, all Laravel source is outside public_html.
$base = dirname(__DIR__, 2).'/puzzlequest_app';
if (!is_file($base.'/vendor/autoload.php') || !is_file($base.'/bootstrap/app.php')) {
    http_response_code(503);
    header('Content-Type: text/plain; charset=utf-8');
    exit('PuzzleQuest backend is missing. Extract the complete setup ZIP into the cPanel account home.');
}
if (!is_file($base.'/storage/installed.lock')) {
    header('Location: /install/', true, 302);
    exit;
}

define('LARAVEL_START', microtime(true));
if (is_file($maintenance = $base.'/storage/framework/maintenance.php')) {
    require $maintenance;
}
require $base.'/vendor/autoload.php';
/** @var \Illuminate\Foundation\Application $app */
$app = require $base.'/bootstrap/app.php';
$app->handleRequest(\Illuminate\Http\Request::capture());
