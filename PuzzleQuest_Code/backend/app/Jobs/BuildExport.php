<?php
namespace App\Jobs;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\{DB,Storage};
use App\Support\Json;
final class BuildExport implements ShouldQueue {
    use Queueable;
    public int $tries=3;
    public function __construct(public string $exportId){}
    public function handle(): void {
        $e=DB::table('exports')->where('id',$this->exportId)->first();if(!$e||$e->state==='ready')return;
        DB::table('exports')->where('id',$e->id)->update(['state'=>'building','updated_at'=>now()]);
        $u=DB::table('users')->find($e->user_id);if(!$u||$u->status!=='active')return;
        $profile=array_intersect_key((array)$u,array_flip(['id','name','email','email_verified_at','avatar','visibility','locale','timezone','preferred_world','preferences','created_at']));
        $tables=['progress','ledger','claims','player_buildings','consents','inbox','support_tickets'];$data=['profile'=>$profile];foreach($tables as$table){$rows=DB::table($table)->where('user_id',$u->id)->get()->map(function($x)use($table){$a=(array)$x;if($table==='support_tickets')unset($a['image_path']);return $a;})->all();$data[$table]=$rows;}
        $data['device_sessions']=DB::table('api_tokens')->where('user_id',$u->id)->get(['device_name','platform','last_activity_at','expires_at'])->toArray();
        $data['support_replies']=DB::table('support_replies')->whereIn('ticket_id',DB::table('support_tickets')->where('user_id',$u->id)->pluck('id'))->get(['ticket_id','body','created_at'])->toArray();
        Storage::disk('local')->makeDirectory('exports');$relative='exports/'.$e->id.'.zip';$path=Storage::disk('local')->path($relative);$tmp=$path.'.building';$zip=new \ZipArchive();if($zip->open($tmp,\ZipArchive::CREATE|\ZipArchive::OVERWRITE)!==true)throw new \RuntimeException('Export file unavailable');
        $zip->addFromString('personal-data.json',Json::encode($data));$stream=fopen('php://temp','r+');fputcsv($stream,['reference','delta','created_at'],',','"','');foreach($data['ledger']as$row)fputcsv($stream,[$row['reference'],$row['delta'],$row['created_at']],',','"','');rewind($stream);$zip->addFromString('ledger.csv',stream_get_contents($stream));fclose($stream);$zip->addFromString('README.txt',"PuzzleQuest personal data export. UTC timestamps. No password hashes, OTPs, session keys or backend secrets. This private download expires after seven days.\nتصدير بيانات الحساب؛ الرابط خاص وينتهي بعد سبعة أيام.");$zip->close();rename($tmp,$path);chmod($path,0600);DB::table('exports')->where('id',$e->id)->update(['state'=>'ready','path'=>$relative,'expires_at'=>now()->addDays(7),'updated_at'=>now()]);
    }
    public function failed(?\Throwable $e): void {DB::table('exports')->where('id',$this->exportId)->update(['state'=>'failed','updated_at'=>now()]);}
}
