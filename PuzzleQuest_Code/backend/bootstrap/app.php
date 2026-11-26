<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

$app = Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'player' => \App\Http\Middleware\PlayerAuth::class,
            'operation' => \App\Http\Middleware\Idempotent::class,
            'administrator' => \App\Http\Middleware\Administrator::class,
            'studio.token' => \App\Http\Middleware\StudioToken::class,
        ]);
        $middleware->append(\App\Http\Middleware\SecurityHeaders::class);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->dontFlash(['password','password_confirmation','current_password','credentials','id_token','guest_token','code','token','install_key']);
        $exceptions->render(function (\Illuminate\Database\QueryException $e, Request $r) {
            if ($r->is('api/*') && in_array((string)$e->getCode(), ['23000','23505'], true)) {
                return response()->json(['error'=>'conflicting_or_duplicate_operation'],409);
            }
            return null;
        });
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();

// Fixed cPanel subdomain layout: only the index/website lives in public_html.
// Never let Laravel silently create a second, invisible "public/content" inside puzzlequest_app.
if (basename($app->basePath()) === 'puzzlequest_app') {
    $webRoot = dirname($app->basePath()).'/public_html/puzzlequest.50sols.com';
    $resolved = realpath($webRoot);
    if ($resolved === false || !is_dir($resolved) || !is_file($resolved.'/index.php')
        || is_link($webRoot)) {
        throw new \RuntimeException('PuzzleQuest public document root is missing. Check cPanel document root.');
    }
    $app->usePublicPath($resolved);
}

return $app;
