<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
    public function up(): void {
        Schema::create('inbox_snapshots',function(Blueprint $t){$t->uuid('id')->primary();$t->foreignId('user_id')->constrained()->cascadeOnDelete();$t->json('message_ids');$t->timestamp('expires_at');});
        Schema::create('support_access',function(Blueprint $t){$t->uuid('id')->primary();$t->uuid('ticket_id');$t->foreign('ticket_id')->references('id')->on('support_tickets')->cascadeOnDelete();$t->char('token_hash',64)->unique();$t->timestamp('expires_at');});
        Schema::table('support_replies',fn(Blueprint $t)=>$t->char('reply_key',64)->nullable()->unique());
    }
    public function down(): void {Schema::dropIfExists('support_access');Schema::dropIfExists('inbox_snapshots');Schema::table('support_replies',fn(Blueprint $t)=>$t->dropColumn('reply_key'));}
};
