<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('ad_sessions',function(Blueprint $t){$t->foreignId('user_id')->primary()->constrained()->cascadeOnDelete();$t->uuid('session_id');$t->timestamp('started_at');$t->timestamp('last_activity_at');$t->unsignedInteger('completions')->default(0);$t->unsignedInteger('interstitials')->default(0);$t->timestamp('last_interstitial_at')->nullable();});
        Schema::create('interstitial_authorizations',function(Blueprint $t){$t->uuid('id')->primary();$t->foreignId('user_id')->constrained()->cascadeOnDelete();$t->uuid('attempt_id')->unique();$t->uuid('session_id');$t->timestamp('created_at');});
    }
    public function down(): void { Schema::dropIfExists('interstitial_authorizations');Schema::dropIfExists('ad_sessions'); }
};
