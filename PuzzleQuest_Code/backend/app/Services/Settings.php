<?php
namespace App\Services;
use App\Support\Json;
use Illuminate\Support\Facades\{DB,Crypt};
final class Settings {
    public function get(string $key,mixed $default=null): mixed { $s=DB::table('settings')->where('key',$key)->first();return $s?Json::read($s->secret?Crypt::decryptString($s->value):$s->value):$default; }
    public function set(string $key,mixed $value,bool $secret=false): void {DB::table('settings')->updateOrInsert(['key'=>$key],['value'=>$secret?Crypt::encryptString(Json::encode($value)):Json::encode($value),'secret'=>$secret,'updated_at'=>now(),'created_at'=>now()]);}
    public function audit(int $admin,string $action,?string $subject=null,array $metadata=[]): void {DB::table('audits')->insert(['admin_id'=>$admin,'action'=>$action,'subject'=>$subject,'metadata'=>Json::encode($metadata),'created_at'=>now()]);}
}
