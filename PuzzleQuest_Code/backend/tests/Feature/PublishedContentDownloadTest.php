<?php

namespace Tests\Feature;

use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\{DB, Schema};
use Tests\TestCase;

class PublishedContentDownloadTest extends TestCase
{
    private string $levelId = 'test_level_001';
    private string $revisionId;
    private string $assetFolder;

    protected function setUp(): void
    {
        parent::setUp();
        $this->revisionId = str_repeat('a', 64).'-'.str_repeat('b', 12);
        $this->assetFolder = public_path('content/'.$this->levelId.'/'.$this->revisionId);
        Schema::create('content_revisions', function (Blueprint $table): void {
            $table->id();
            $table->string('level_id');
            $table->string('revision');
            $table->string('state');
            $table->longText('payload');
        });
        if (!is_dir($this->assetFolder)) mkdir($this->assetFolder, 0755, true);
        file_put_contents($this->assetFolder.'/master.png', 'pinned-bytes');
        file_put_contents($this->assetFolder.'/unlisted.png', 'not-in-manifest');
        $this->insertRevision('published');
    }

    protected function tearDown(): void
    {
        foreach (['master.png', 'unlisted.png'] as $file) {
            if (is_file($this->assetFolder.'/'.$file)) unlink($this->assetFolder.'/'.$file);
        }
        if (is_dir($this->assetFolder)) rmdir($this->assetFolder);
        $parent = dirname($this->assetFolder);
        if (is_dir($parent) && count(scandir($parent)) === 2) rmdir($parent);
        parent::tearDown();
    }

    private function insertRevision(string $state): void
    {
        DB::table('content_revisions')->delete();
        DB::table('content_revisions')->insert([
            'level_id' => $this->levelId,
            'revision' => $this->revisionId,
            'state' => $state,
            'payload' => json_encode([
                'asset_prefix' => 'content/'.$this->levelId.'/'.$this->revisionId,
                'hashes' => ['master.png' => hash('sha256', 'pinned-bytes')],
            ]),
        ]);
    }

    private function url(string $file): string
    {
        return '/api/v1/content/'.$this->levelId.'/'.$this->revisionId.'/'.$file;
    }

    public function test_serves_only_published_checksum_pinned_assets(): void
    {
        $response = $this->get($this->url('master.png'));
        $response->assertOk()->assertHeader('Content-Type', 'image/png');

        $this->get($this->url('unlisted.png'))->assertNotFound();
        file_put_contents($this->assetFolder.'/master.png', 'tampered-bytes');
        $this->get($this->url('master.png'))->assertNotFound();
    }

    public function test_drafts_are_not_publicly_readable(): void
    {
        $this->insertRevision('ready');
        $this->get($this->url('master.png'))->assertNotFound();
    }

    public function test_rejects_invalid_revision_without_file_access(): void
    {
        $this->get('/api/v1/content/'.$this->levelId.'/short/master.png')
            ->assertNotFound();
    }
}
