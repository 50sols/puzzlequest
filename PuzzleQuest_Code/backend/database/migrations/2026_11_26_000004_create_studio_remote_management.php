<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('studio_access_tokens', function (Blueprint $t) {
            $t->uuid('id')->primary();
            $t->unsignedBigInteger('admin_id');
            $t->foreign('admin_id')->references('id')->on('admins')->cascadeOnDelete();
            $t->string('name',100);
            $t->char('token_hash',64)->unique();
            $t->timestamp('last_used_at')->nullable();
            $t->timestamp('expires_at');
            $t->timestamp('revoked_at')->nullable();
            $t->timestamps();
            $t->index(['admin_id','expires_at']);
        });
        Schema::create('studio_media', function (Blueprint $t) {
            $t->uuid('id')->primary();
            $t->string('relative_path',255)->unique();
            $t->string('mime',40);
            $t->unsignedInteger('width');
            $t->unsignedInteger('height');
            $t->unsignedBigInteger('bytes');
            $t->char('sha256',64);
            $t->unsignedBigInteger('created_by');
            $t->timestamp('created_at');
        });
        Schema::create('studio_documents', function (Blueprint $t) {
            $t->uuid('id')->primary();
            $t->string('kind',40);
            $t->string('slug',80);
            $t->string('world_id')->nullable();
            $t->json('title');
            $t->unsignedInteger('position')->default(1);
            $t->json('draft_payload');
            $t->json('published_payload')->nullable();
            $t->unsignedInteger('draft_revision')->default(1);
            $t->unsignedInteger('live_revision')->default(0);
            $t->string('state',16)->default('draft');
            $t->unsignedBigInteger('created_by');
            $t->timestamp('published_at')->nullable();
            $t->timestamps();
            $t->unique(['kind','slug']);
            $t->index(['kind','state','world_id']);
        });
        Schema::create('studio_document_history', function (Blueprint $t) {
            $t->uuid('id')->primary();
            $t->uuid('document_id');
            $t->foreign('document_id')->references('id')->on('studio_documents');
            $t->unsignedInteger('revision');
            $t->json('snapshot');
            $t->unsignedBigInteger('admin_id');
            $t->timestamp('published_at');
            $t->unique(['document_id','revision']);
        });
    }
    // Forward-only: player/game data and previous published revisions must never be dropped by rollback.
    public function down(): void { throw new RuntimeException('Forward-only migration: restore verified backup if required.'); }
};
