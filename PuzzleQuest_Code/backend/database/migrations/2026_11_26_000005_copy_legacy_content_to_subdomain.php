<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use App\Services\ContentAssetRelocator;

return new class extends Migration {
    public function up(): void {
        if (basename(base_path()) !== 'puzzlequest_app') return; // Developer/CI installs have ordinary public/.
        $documentRoot = realpath(dirname(base_path()).'/public_html/puzzlequest.50sols.com');
        if (!$documentRoot || $documentRoot !== realpath(public_path())) {
            throw new \RuntimeException('cPanel document root not bound to public_path');
        }
        $items = (function () {
            foreach (DB::table('content_revisions')->select(['id','payload'])->cursor() as $r) {
                $payload = json_decode($r->payload, true, 512, JSON_THROW_ON_ERROR);
                yield ['asset_prefix'=>$payload['asset_prefix']??'', 'hashes'=>$payload['hashes']??null];
            }
        })();
        ContentAssetRelocator::copyMissing($items, base_path('public'), $documentRoot);
    }
    public function down(): void {
        // Intentionally non-reversible: never delete published content or player assets.
        throw new \RuntimeException('Reverting copied content is not supported; do not remove live puzzle assets');
    }
};
