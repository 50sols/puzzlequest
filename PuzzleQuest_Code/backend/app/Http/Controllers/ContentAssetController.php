<?php
namespace App\Http\Controllers;

use App\Support\Json;
use Illuminate\Support\Facades\DB;

/**
 * Read-only delivery of published, checksum-pinned puzzle assets.
 *
 * Static files can be inaccessible behind some shared-hosting rewrite rules.
 * This endpoint only exposes files already referenced by a published revision;
 * it never exposes storage, drafts, or arbitrary public web-root paths.
 */
final class ContentAssetController extends Controller {
    public function show(string $level, string $revision, string $file) {
        if (!preg_match('/^[a-z0-9_]{3,100}$/D', $level)
            || !preg_match('/^[a-f0-9-]{20,128}$/D', $revision)
            || !preg_match('/^[A-Za-z0-9_.\/-]+$/D', $file)
            || array_intersect(explode('/', $file), ['', '.', '..'])) {
            abort(404);
        }

        $record = DB::table('content_revisions')
            ->where('level_id', $level)->where('revision', $revision)
            ->where('state', 'published')->first();
        abort_unless($record, 404);
        $payload = Json::read($record->payload);
        $prefix = "content/{$level}/{$revision}";
        abort_unless(($payload['asset_prefix'] ?? null) === $prefix, 404);
        $expected = $payload['hashes'][$file] ?? null;
        abort_unless(is_string($expected) && preg_match('/^[a-f0-9]{64}$/D', $expected), 404);

        $contentRoot = realpath(public_path('content'));
        $revisionRoot = realpath(public_path($prefix));
        $actual = $revisionRoot ? realpath($revisionRoot.'/'.$file) : false;
        abort_unless($contentRoot && $revisionRoot
            && str_starts_with($revisionRoot, $contentRoot.DIRECTORY_SEPARATOR)
            && $actual && str_starts_with($actual, $revisionRoot.DIRECTORY_SEPARATOR)
            && is_file($actual) && !is_link($actual), 404);
        abort_unless(hash_equals($expected, hash_file('sha256', $actual)), 404);

        $mime = match (strtolower(pathinfo($file, PATHINFO_EXTENSION))) {
            'png' => 'image/png',
            'jpg', 'jpeg' => 'image/jpeg',
            'webp' => 'image/webp',
            'svg' => 'image/svg+xml',
            'json' => 'application/json',
            default => null,
        };
        abort_unless($mime !== null, 404);

        return response()->file($actual, [
            'Content-Type' => $mime,
            'Cache-Control' => 'public, max-age=31536000, immutable',
            'X-Content-Type-Options' => 'nosniff',
            'Content-Disposition' => $mime === 'image/svg+xml' ? 'attachment' : 'inline',
        ]);
    }
}
