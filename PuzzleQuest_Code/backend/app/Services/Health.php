<?php
namespace App\Services;
use Illuminate\Support\Facades\{DB,Schema};
use App\Support\Json;
final class Health {
    public function check(): array {
        $errors=[];$checks=[];try{DB::select('SELECT 1');$checks['database']=DB::getDriverName();foreach(['users','admins','wallets','ledger','attempts','content_revisions','operations','jobs','cache','push_deliveries','system_releases']as$table)if(!Schema::hasTable($table))$errors[]='Missing table '.$table;}catch(\Throwable $e){$errors[]='Database unavailable';}
        if(!$errors){$checks['owner_exists']=DB::table('admins')->where('role','owner')->where('active',true)->exists();$checks['levels']=DB::table('levels')->where('published',true)->count();foreach(DB::table('content_revisions')->where('state','published')->get()as$r){$v=Json::read($r->payload);foreach($v['hashes']as$file=>$hash){$path=public_path($v['asset_prefix'].'/'.$file);if(!is_file($path)||!hash_equals($hash,hash_file('sha256',$path)))$errors[]='Content checksum failed '.$r->level_id.'/'.$file;}}}
        foreach(['storage','bootstrap/cache']as$dir)if(!is_writable(base_path($dir)))$errors[]='Directory not writable: '.$dir;
        $checks['legal_approved']=(bool)config('puzzlequest.legal_approved');$checks['admob_configured']=(bool)config('puzzlequest.ad_units');$checks['catalog_signing_configured']=strlen(base64_decode(config('puzzlequest.catalog_signing_key')??'',true)?:'')===64;
        return ['status'=>$errors?'failed':'ok','version'=>app(Updates::class)->version(),'checks'=>$checks,'errors'=>$errors,'launch_ready'=>false,'external_gates'=>['Native Google OAuth clients and real ID-token login','SMTP delivery to the actual mailbox','AdMob SSV production callback and configured units','FCM/APNs device delivery and permissions','Q40 approved artwork/device acceptance','Legal/region/store launch review']];
    }
}
