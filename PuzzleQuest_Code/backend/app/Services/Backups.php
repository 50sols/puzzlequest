<?php
namespace App\Services;
use App\Support\Json;
use Illuminate\Support\Facades\{DB,Storage,Schema};
use Illuminate\Support\Str;
final class Backups {
    public function create(): array {
        Storage::disk('local')->makeDirectory('backups');$id=now()->format('Ymd-His').'-'.Str::uuid();$temporary=Storage::disk('local')->path('backups/'.$id.'.zip.part');$zip=new \ZipArchive();if($zip->open($temporary,\ZipArchive::CREATE|\ZipArchive::OVERWRITE)!==true)throw new \RuntimeException('Backup storage unavailable');
        try{$schema=[];foreach(Schema::getTables()as$table){$name=$table['name'];if(!preg_match('/^[A-Za-z0-9_]+$/D',$name))throw new \RuntimeException('Unsafe database identifier');
                if(DB::getDriverName()==='mysql')$schema[$name]=((array)DB::selectOne('SHOW CREATE TABLE `'.$name.'`'))['Create Table'];else $schema[$name]=DB::table('sqlite_master')->where('type','table')->where('name',$name)->value('sql');
                $rows=fopen('php://temp/maxmemory:2097152','w+');foreach(DB::table($name)->cursor()as$row)fwrite($rows,Json::encode((array)$row)."\n");rewind($rows);$data=stream_get_contents($rows);fclose($rows);$zip->addFromString('database/'.$name.'.jsonl',$data);
            }$zip->addFromString('database/schema.json',Json::encode(['driver'=>DB::getDriverName(),'tables'=>$schema]));
            // In the fixed cPanel layout the true public files are NOT under base_path('public').
            // Restore tools expect live web-root content in files/public/.
            foreach(['app','bootstrap','config','database','resources','routes','vendor']as$directory)
                foreach(new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator(base_path($directory),\FilesystemIterator::SKIP_DOTS))as$file){
                    if(!$file->isFile()||$file->isLink())continue;
                    $relative=str_replace('\\','/',substr($file->getPathname(),strlen(base_path())+1));
                    if(str_starts_with($relative,'bootstrap/cache/'))continue;
                    $zip->addFile($file->getPathname(),'files/'.$relative);
                }
            $roots = [['path'=>public_path(), 'archive'=>'files/public/']];
            // Preserve pre-fix files as a distinct legacy tree until recovery is verified.
            if(realpath(base_path('public')) !== realpath(public_path()))
                $roots[]=['path'=>base_path('public'), 'archive'=>'files/legacy-public/'];
            foreach($roots as $root) {
                if(!is_dir($root['path']) || is_link($root['path']))continue;
                $directory = new \RecursiveDirectoryIterator($root['path'], \FilesystemIterator::SKIP_DOTS);
                foreach(new \RecursiveIteratorIterator($directory) as $file) {
                    if(!$file->isFile()||$file->isLink())continue;
                    $relative=str_replace('\\','/',substr($file->getPathname(),strlen($root['path'])+1));
                    if(str_contains($relative,'../') || str_contains($relative,'\\'))continue;
                    $zip->addFile($file->getPathname(),$root['archive'].$relative);
                }
            }
            foreach(['artisan','composer.json','composer.lock']as$file)$zip->addFile(base_path($file),'files/'.$file);$zip->addFromString('backup.json',Json::encode(['version'=>config('puzzlequest.version'),'created_at'=>now()->toIso8601String(),'requires_same_app_key'=>true,'contains_env'=>false]));
        }finally{$zip->close();}
        $relative='backups/'.$id.'.pqb';$this->encrypt($temporary,Storage::disk('local')->path($relative));unlink($temporary);chmod(Storage::disk('local')->path($relative),0600);return ['path'=>$relative,'sha256'=>hash_file('sha256',Storage::disk('local')->path($relative)),'created_at'=>now()->toIso8601String()];
    }
    public function encrypt(string $input,string $output): void {
        $in=fopen($input,'rb');$out=fopen($output,'xb');if(!$in||!$out)throw new \RuntimeException('Backup stream unavailable');
        try{[$state,$header]=sodium_crypto_secretstream_xchacha20poly1305_init_push(hash('sha256',config('app.key'),true));fwrite($out,'PQB1'.$header);while(true){$chunk=fread($in,1048576);if($chunk===false)throw new \RuntimeException('Backup read failed');$last=feof($in);$cipher=sodium_crypto_secretstream_xchacha20poly1305_push($state,$chunk,'',$last?SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_TAG_FINAL:0);fwrite($out,pack('N',strlen($cipher)).$cipher);if($last)break;}}
        finally{fclose($in);fclose($out);}
    }
    public function decrypt(string $input,string $output): void {
        $in=fopen($input,'rb');$out=fopen($output,'xb');if(!$in||!$out)throw new \RuntimeException('Backup stream unavailable');$ok=false;
        try{if(fread($in,4)!=='PQB1')throw new \RuntimeException('Invalid backup format');$header=fread($in,SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_HEADERBYTES);$state=sodium_crypto_secretstream_xchacha20poly1305_init_pull($header,hash('sha256',config('app.key'),true));while(!feof($in)){$length=fread($in,4);if(strlen($length)!==4)throw new \RuntimeException('Truncated backup');$n=unpack('N',$length)[1];if($n<17||$n>1048593)throw new \RuntimeException('Invalid backup frame');$cipher='';while(strlen($cipher)<$n){$part=fread($in,$n-strlen($cipher));if($part===''||$part===false)throw new \RuntimeException('Truncated backup');$cipher.=$part;}$result=sodium_crypto_secretstream_xchacha20poly1305_pull($state,$cipher);if($result===false)throw new \RuntimeException('Backup authentication failed');[$plain,$tag]=$result;fwrite($out,$plain);if($tag===SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_TAG_FINAL){if(fread($in,1)!=='')throw new \RuntimeException('Unexpected backup trailer');$ok=true;break;}}if(!$ok)throw new \RuntimeException('Incomplete backup');}
        finally{fclose($in);fclose($out);if(!$ok&&is_file($output))unlink($output);}
    }
}
