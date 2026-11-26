<?php
namespace App\Services;
use Illuminate\Support\Facades\{Artisan,DB,Hash};
use Database\Seeders\DatabaseSeeder;
final class Installer {
    public static function preflight(string $base): array {
        $checks=['PHP 8.3+'=>version_compare(PHP_VERSION,'8.3.0','>='),'vendor/autoload.php'=>is_file($base.'/vendor/autoload.php')];
        foreach(['ctype','curl','dom','fileinfo','mbstring','openssl','pdo','pdo_mysql','sodium','zip','gd','xml']as$extension)$checks[$extension]=extension_loaded($extension);
        foreach(['storage','storage/app/private','storage/framework','storage/framework/cache','storage/framework/sessions','storage/framework/views','bootstrap/cache']as$directory){if(!is_dir($base.'/'.$directory))@mkdir($base.'/'.$directory,0750,true);$checks[$directory.' writable']=is_writable($base.'/'.$directory);}$checks['application directory writable']=is_writable($base);return $checks;
    }
    public static function environment(array $values): string {
        $lines=[];foreach($values as$key=>$value){if(!preg_match('/^[A-Z][A-Z0-9_]*$/D',$key)||preg_match('/[\r\n\x00]/',(string)$value))throw new \RuntimeException('Invalid environment value');$lines[]=$key.'="'.str_replace(['\\','"','$'],['\\\\','\\"','\\$'],(string)$value).'"';}return implode("\n",$lines)."\n";
    }
    public function install(string $base,array $d): void {
        if(is_file($base.'/storage/installed.lock'))throw new \RuntimeException('Already installed');foreach(self::preflight($base)as$check=>$ok)if(!$ok)throw new \RuntimeException('Preflight requirement failed: '.$check);
        if(!filter_var($d['url']??'',FILTER_VALIDATE_URL)||parse_url($d['url'],PHP_URL_SCHEME)!=='https'||!empty(parse_url($d['url'],PHP_URL_USER))||!preg_match('/^[A-Za-z0-9_]+$/D',$d['database']??'')||!filter_var($d['admin_email']??'',FILTER_VALIDATE_EMAIL)||strlen($d['admin_password']??'')<12||strlen($d['admin_password'])>128)throw new \RuntimeException('Invalid installation input');
        $lock=fopen($base.'/storage/framework/install-operation.lock','c+');if(!$lock||!flock($lock,LOCK_EX|LOCK_NB))throw new \RuntimeException('Installation already running');
        try{$fingerprint=hash('sha256',$d['host'].'|'.$d['port'].'|'.$d['database'].'|'.$d['username']);$marker=$base.'/storage/app/private/installing.json';$resume=is_file($marker)?json_decode(file_get_contents($marker),true):null;
            $pdo=new \PDO('mysql:host='.$d['host'].';port='.(int)$d['port'].';dbname='.$d['database'].';charset=utf8mb4',$d['username'],$d['password'],[\PDO::ATTR_ERRMODE=>\PDO::ERRMODE_EXCEPTION]);
            if($pdo->query('SHOW TABLES')->fetchColumn()!==false&&($resume['fingerprint']??null)!==$fingerprint)throw new \RuntimeException('Use a new empty database; existing applications are never overwritten');if($resume&&($resume['fingerprint']??null)!==$fingerprint)throw new \RuntimeException('A different installation is pending');
            if(!$resume){$key='base64:'.base64_encode(random_bytes(32));$catalog=sodium_crypto_sign_secretkey(sodium_crypto_sign_keypair());$values=['APP_NAME'=>'PuzzleQuest','APP_ENV'=>'production','APP_KEY'=>$key,'APP_DEBUG'=>'false','APP_URL'=>rtrim($d['url'],'/'),'APP_LOCALE'=>'ar','APP_FALLBACK_LOCALE'=>'en','ENFORCE_HTTPS'=>'true','LOG_CHANNEL'=>'single','LOG_LEVEL'=>'warning','DB_CONNECTION'=>'mysql','DB_HOST'=>$d['host'],'DB_PORT'=>(int)$d['port'],'DB_DATABASE'=>$d['database'],'DB_USERNAME'=>$d['username'],'DB_PASSWORD'=>$d['password'],'SESSION_DRIVER'=>'database','SESSION_ENCRYPT'=>'true','SESSION_SECURE_COOKIE'=>'true','SESSION_SAME_SITE'=>'strict','SESSION_LIFETIME'=>'60','CACHE_STORE'=>'database','QUEUE_CONNECTION'=>'database','FILESYSTEM_DISK'=>'local','MAIL_MAILER'=>'smtp','MAIL_HOST'=>'','MAIL_PORT'=>'587','MAIL_FROM_ADDRESS'=>'info@50sols.com','MAIL_FROM_NAME'=>'PuzzleQuest','GOOGLE_CLIENT_ID'=>'669275008728-h75erb2344tipd76enr2fahcd4h5frea.apps.googleusercontent.com','FIREBASE_PROJECT_ID'=>'puzzlequest50sols','ADMOB_REWARDED_UNITS'=>'','CATALOG_SIGNING_KEY'=>base64_encode($catalog),'LEGAL_APPROVED'=>'false','ACCOUNT_DELETION_ENABLED'=>'false'];
                if(file_put_contents($base.'/.env.installing',self::environment($values),LOCK_EX)===false||!rename($base.'/.env.installing',$base.'/.env'))throw new \RuntimeException('Cannot write environment');chmod($base.'/.env',0600);file_put_contents($marker,json_encode(['fingerprint'=>$fingerprint,'started_at'=>gmdate('c')]),LOCK_EX);chmod($marker,0600);
            }
            if(is_file($base.'/bootstrap/cache/config.php'))unlink($base.'/bootstrap/cache/config.php');$app=require $base.'/bootstrap/app.php';$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();
            if(Artisan::call('migrate',['--force'=>true])!==0)throw new \RuntimeException('Migration failed; retry the same database');Artisan::call('db:seed',['--class'=>DatabaseSeeder::class,'--force'=>true]);
            DB::transaction(function()use($d){if(!DB::table('admins')->where('role','owner')->exists())DB::table('admins')->insert(['name'=>'Owner','email'=>strtolower($d['admin_email']),'password'=>Hash::make($d['admin_password']),'role'=>'owner','created_at'=>now(),'updated_at'=>now()]);});
            DB::select('SELECT 1');file_put_contents($base.'/VERSION',config('puzzlequest.version'));file_put_contents($base.'/storage/installed.lock',gmdate('c'),LOCK_EX);chmod($base.'/storage/installed.lock',0600);if(is_file($base.'/storage/app/private/install.key'))unlink($base.'/storage/app/private/install.key');if(is_file($marker))unlink($marker);Artisan::call('view:cache');
        }finally{flock($lock,LOCK_UN);fclose($lock);}
    }
}
