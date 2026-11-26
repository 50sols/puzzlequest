<?php

use Illuminate\Support\Facades\{Artisan,DB,Hash,Storage,Schedule};
use App\Support\Json;
Artisan::command('pq:health {--json}',function(){ $result=app(\App\Services\Health::class)->check();$this->line(Json::encode($result));return $result['status']==='ok'?0:1; })->purpose('Check database, immutable content and backend configuration without sending external messages');
Artisan::command('pq:install {--email=} {--name=Owner}',function(){
    if(is_file(storage_path('installed.lock'))){$this->error('Already installed');return 1;}$email=$this->option('email');if(!filter_var($email,FILTER_VALIDATE_EMAIL)){$this->error('A valid --email is required');return 1;}$password=getenv('PQ_ADMIN_PASSWORD')?:$this->secret('Owner password (12-128 characters)');if(strlen($password)<12||strlen($password)>128){$this->error('Password length invalid');return 1;}
    Artisan::call('migrate',['--force'=>true]);Artisan::call('db:seed',['--force'=>true]);if(DB::table('admins')->exists()){$this->error('An administrator already exists; inspect pending installation');return 1;}DB::table('admins')->insert(['name'=>$this->option('name'),'email'=>strtolower($email),'password'=>Hash::make($password),'role'=>'owner','created_at'=>now(),'updated_at'=>now()]);file_put_contents(storage_path('installed.lock'),gmdate('c'));file_put_contents(base_path('VERSION'),'1.0.0');$this->info('Installed. Configure signing keys, mail, providers, cron and legal pages before launch.');return 0;
})->purpose('Install an explicitly configured database; no default owner credentials');
Artisan::command('pq:backup',function(){try{$this->line(Json::encode(app(\App\Services\Backups::class)->create()));return 0;}catch(\Throwable $e){$this->error('Backup failed; no successful backup was recorded.');return 1;}});
Artisan::command('pq:tick',function(){
    if(app()->isDownForMaintenance())return 0;\App\Jobs\DispatchPushBatch::dispatch();
    DB::table('reward_requests')->where('state','pending')->where('expires_at','<',now())->update(['state'=>'expired','updated_at'=>now()]);
    DB::table('api_tokens')->where('expires_at','<',now())->delete();DB::table('oauth_challenges')->where('expires_at','<',now()->subDay())->delete();DB::table('otp_challenges')->where('created_at','<',now()->subDay())->delete();
    DB::table('inbox')->where('expires_at','<',now())->delete();
    foreach(DB::table('exports')->where('state','ready')->where('expires_at','<',now())->get()as$e){Storage::disk('local')->delete($e->path);DB::table('exports')->where('id',$e->id)->update(['state'=>'expired','updated_at'=>now()]);}
    foreach(DB::table('offline_allocations')->where('expires_at','<',now())->get()as$allocation){DB::transaction(function()use($allocation){DB::table('users')->where('id',$allocation->user_id)->lockForUpdate()->first();$remaining=$allocation->quantity-$allocation->used;if($remaining){$meta=Json::read(DB::table('ledger')->where('user_id',$allocation->user_id)->where('reference','reserve:'.$allocation->id)->value('metadata'));app(\App\Services\Wallet::class)->change($allocation->user_id,'reserve-refund:'.$allocation->id,[$allocation->resource=>$remaining],[],(bool)($meta['spent_transferable']??false),$meta['spent_origins']??['initial']);}DB::table('offline_allocations')->where('id',$allocation->id)->delete();});}
    if(config('puzzlequest.delete_enabled')&&config('puzzlequest.legal_approved'))foreach(DB::table('users')->where('status','deletion_pending')->where('purge_after','<=',now())->get()as$u){foreach(DB::table('support_tickets')->where('user_id',$u->id)->whereNotNull('image_path')->get()as$t)Storage::disk('local')->delete($t->image_path);foreach(DB::table('exports')->where('user_id',$u->id)->whereNotNull('path')->get()as$e)Storage::disk('local')->delete($e->path);DB::table('users')->where('id',$u->id)->delete();}
    foreach(Storage::disk('local')->files('backups')as$file)if(Storage::disk('local')->lastModified($file)<now()->subDays(90)->timestamp)Storage::disk('local')->delete($file);
    $this->info('Housekeeping completed; Push transport runs through the database queue.');return 0;
})->purpose('Privacy retention, stale sessions/entitlements and queued notification dispatch');
Schedule::command('pq:tick')->everyMinute()->withoutOverlapping(10);
Schedule::command('queue:work --stop-when-empty --max-time=50 --tries=3 --timeout=45')->everyMinute()->withoutOverlapping(10);
Schedule::command('queue:prune-failed --hours=24')->daily();
