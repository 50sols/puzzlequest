<?php
namespace App\Services;
use App\Support\Json;
use Illuminate\Support\Facades\{DB,Storage,Artisan};
use Illuminate\Support\Str;
final class Updates {
    public function __construct(private SafeZip $zip,private Backups $backups){}
    public function verify(string $archive): array {
        $public=app(\App\Services\Settings::class)->get('release_public_key') ?: config('puzzlequest.release_public_key');if(!$public||strlen(base64_decode($public,true)?:'')!==SODIUM_CRYPTO_SIGN_PUBLICKEYBYTES)throw new \RuntimeException('Configure a trusted Ed25519 release public key first');
        $id=(string)Str::uuid();$stage=Storage::disk('local')->path('updates/'.$id);$names=$this->zip->extract($archive,$stage);
        if(!is_file($stage.'/release.json')||!is_file($stage.'/release.sig'))throw new \RuntimeException('Signed release manifest missing');$bytes=file_get_contents($stage.'/release.json');$signature=base64_decode(trim(file_get_contents($stage.'/release.sig')),true);
        if(!$signature||strlen($signature)!==SODIUM_CRYPTO_SIGN_BYTES||!sodium_crypto_sign_verify_detached($signature,$bytes,base64_decode($public)))throw new \RuntimeException('Release signature rejected');
        $m=Json::read($bytes);if(($m['deployment_layout']??null)!=='cpanel_fixed_subdomain_v1')throw new \RuntimeException('Unsupported deployment layout for cPanel subdomain');if(!isset($m['version'],$m['from_version'],$m['php_min'],$m['files'])||!is_array($m['files'])||!$m['files']||!preg_match('/^\d+\.\d+\.\d+$/D',$m['version'])||$m['from_version']!==$this->version()||!version_compare($m['version'],$this->version(),'>')||version_compare(PHP_VERSION,$m['php_min'],'<'))throw new \RuntimeException('Release version or PHP compatibility mismatch');
        $listed=['release.json','release.sig'];foreach($m['files']as$file=>$hash){$this->allowed($file);if(!preg_match('/^[a-f0-9]{64}$/D',$hash)||!is_file($stage.'/payload/'.$file)||!hash_equals($hash,hash_file('sha256',$stage.'/payload/'.$file)))throw new \RuntimeException('Release checksum mismatch: '.$file);if(str_ends_with($file,'.php'))token_get_all(file_get_contents($stage.'/payload/'.$file),TOKEN_PARSE);$listed[]='payload/'.$file;}
        foreach($names as$name)if(!str_ends_with($name,'/')&&!in_array($name,$listed,true))throw new \RuntimeException('Unlisted payload file');
        Storage::disk('local')->makeDirectory('release-zips');$stored='release-zips/'.$id.'.zip';if(!copy($archive,Storage::disk('local')->path($stored)))throw new \RuntimeException('Cannot persist verified ZIP');
        DB::table('system_releases')->insert(['id'=>$id,'version'=>$m['version'],'state'=>'verified','archive_path'=>$stored,'sha256'=>hash_file('sha256',$archive),'created_at'=>now(),'updated_at'=>now()]);return ['id'=>$id,'version'=>$m['version'],'state'=>'verified','file_count'=>count($m['files'])];
    }
    private function allowed(string $file): void {
        $this->zip->path($file);if(!preg_match('~^(app/|bootstrap/(?!cache/)|config/|database/migrations/|resources/|routes/|vendor/|public/(?!install/)|artisan$|composer\.(json|lock)$)~D',$file)||preg_match('~(^|/)(\.env(?:\..*)?|storage|install\.key)(/|$)~i',$file))throw new \RuntimeException('Protected update destination: '.$file);
    }
    /** Keep web assets in the cPanel subdomain Document Root, never in the private Laravel public folder. */
    private function destination(string $file): string {
        $this->allowed($file);
        $isPublic = str_starts_with($file, 'public/');
        $root = $isPublic ? public_path() : base_path();
        if (is_link($root) || !is_dir($root) || ($real = realpath($root)) === false)
            throw new \RuntimeException('Invalid release destination root');
        if ($isPublic && basename(base_path()) === 'puzzlequest_app') {
            $expected = realpath(dirname(base_path()).'/public_html/puzzlequest.50sols.com');
            if ($expected === false || $expected !== $real || !is_file($real.'/index.php'))
                throw new \RuntimeException('cPanel public document root not bound correctly');
        }
        $parts = explode('/', $isPublic ? substr($file,7) : $file);
        $name = array_pop($parts);
        $parent = $real;
        foreach ($parts as $part) {
            $parent .= '/'.$part;
            if (is_link($parent) || (file_exists($parent) && !is_dir($parent)))
                throw new \RuntimeException('Unsafe release destination path');
            if (!is_dir($parent) && !mkdir($parent,0755))
                throw new \RuntimeException('Cannot create update directory');
        }
        $target = $parent.'/'.$name;
        if (is_link($target) || is_dir($target))
            throw new \RuntimeException('Unsafe release target');
        return $target;
    }
    public function version(): string {return is_file(base_path('VERSION'))?trim(file_get_contents(base_path('VERSION'))):config('puzzlequest.version');}
    public function install(string $id): array {
        $lock=fopen(storage_path('framework/update-operation.lock'),'c+');if(!$lock||!flock($lock,LOCK_EX|LOCK_NB))throw new \RuntimeException('Another system operation is running');$maintenance=false;$backup=null;
        try{$r=DB::table('system_releases')->where('id',$id)->first();if(!$r||$r->state!=='verified')throw new \RuntimeException('Release not verified');$archive=Storage::disk('local')->path($r->archive_path);if(!hash_equals($r->sha256,hash_file('sha256',$archive)))throw new \RuntimeException('Verified ZIP changed');
            $stage=Storage::disk('local')->path('updates/'.$id);$manifest=Json::read(file_get_contents($stage.'/release.json'));if(($manifest['deployment_layout']??null)!=='cpanel_fixed_subdomain_v1')throw new \RuntimeException('Unsupported deployment layout for cPanel subdomain');if($manifest['from_version']!==$this->version())throw new \RuntimeException('Installed version changed after verification');foreach($manifest['files']as$file=>$hash)if(!hash_equals($hash,hash_file('sha256',$stage.'/payload/'.$file)))throw new \RuntimeException('Staged payload changed');
            Artisan::call('down',['--retry'=>60]);$maintenance=true;$backup=$this->backups->create();DB::table('system_releases')->where('id',$id)->update(['state'=>'installing','backup_path'=>$backup['path'],'updated_at'=>now()]);
            foreach($manifest['files']as$file=>$hash){$this->allowed($file);$target=$this->destination($file);$temp=$target.'.pq-updating';if(is_link($temp)||is_file($temp)||!copy($stage.'/payload/'.$file,$temp)||!hash_equals($hash,hash_file('sha256',$temp))||!rename($temp,$target)){if(is_file($temp))unlink($temp);throw new \RuntimeException('Cannot safely replace '.$file);}if(function_exists('opcache_invalidate'))opcache_invalidate($target,true);}
            if(Artisan::call('migrate',['--force'=>true])!==0)throw new \RuntimeException('Migration failed; restore database from the recorded backup, do not guess a down migration');
            Artisan::call('optimize:clear');DB::select('SELECT 1');file_put_contents(base_path('VERSION'),$manifest['version'],LOCK_EX);DB::table('system_releases')->where('id',$id)->update(['state'=>'installed','updated_at'=>now()]);Artisan::call('up');$maintenance=false;return ['installed'=>true,'version'=>$manifest['version'],'backup'=>$backup];
        }catch(\Throwable $e){DB::table('system_releases')->where('id',$id)->update(['state'=>'recovery_required','error'=>'Update failed. Keep maintenance active. Use the recorded authenticated backup and recovery procedure.','backup_path'=>$backup['path']??null,'updated_at'=>now()]);throw new \RuntimeException('Update failed; maintenance remains active when installation had started. Recovery backup: '.($backup['path']??'not created'),0,$e);}
        finally{flock($lock,LOCK_UN);fclose($lock);}
    }
}
