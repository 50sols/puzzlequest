<?php
namespace App\Services;
use App\Support\Json;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\{DB,Crypt};
use Illuminate\Support\Str;
final class Notifications {
    public const CATEGORIES=['system','rewards','achievements','progress','account_security','support','events'];
    public const SCREENS=['inbox','reward_claim_context','achievements','worlds_levels','my_account','help_support','missions_events'];
    public function __construct(private Fcm $fcm){}
    public function securityAlert(int $uid,string $eventId): void {
        $title=['ar'=>'تنبيه أمني','en'=>'Security notice'];$body=['ar'=>'تم تغيير إعداد أمني في حسابك. راجع التفاصيل داخل التطبيق.','en'=>'An account security setting changed. Review details in the app.'];$target=['screen'=>'my_account'];
        $this->inbox($uid,'security:'.$eventId,'account_security',$title,$body,$target);
        DB::table('push_campaigns')->insertOrIgnore(['id'=>$eventId,'category'=>'account_security','title'=>Json::encode($title),'body'=>Json::encode($body),'target'=>Json::encode($target),'audience'=>Json::encode(['user_ids'=>[$uid]]),'state'=>'scheduled','critical'=>true,'expires_at'=>now()->addDay(),'created_at'=>now(),'updated_at'=>now()]);
        DB::table('push_deliveries')->insertOrIgnore(['id'=>(string)Str::uuid(),'campaign_id'=>$eventId,'user_id'=>$uid,'original_due_at'=>now(),'due_at'=>now(),'state'=>'pending','created_at'=>now(),'updated_at'=>now()]);
    }
    public function inbox(int $uid,string $logical,string $category,array $title,array $body,array $target): void {
        DB::table('inbox')->insertOrIgnore(['id'=>(string)Str::uuid(),'user_id'=>$uid,'logical_id'=>$logical,'category'=>$category,'title'=>Json::encode($title),'body'=>Json::encode($body),'target'=>Json::encode($target),'expires_at'=>now()->addDays($category==='account_security'?180:90),'created_at'=>now()]);
    }
    public function schedule(object $campaign): int {
        if(!in_array($campaign->category,self::CATEGORIES,true))Json::fail('unsupported_notification_category');
        if($campaign->critical)Json::fail('critical_security_is_system_generated_only',403);
        $target=Json::read($campaign->target);if(!in_array($target['screen']??'',self::SCREENS,true))Json::fail('invalid_notification_target');
        if($campaign->category==='events')Json::fail('no_events_published_at_launch',409);
        foreach([Json::read($campaign->title),Json::read($campaign->body)]as$text)if(empty($text['ar'])||empty($text['en']))Json::fail('both_translations_required');
        $audience=Json::read($campaign->audience);$q=DB::table('users')->where('status','active')->where('is_guest',false)->whereNotNull('email_verified_at');if(!empty($audience['user_ids']))$q->whereIn('id',$audience['user_ids']);$count=0;
        foreach($q->get()as$u){$due=$campaign->local_wall_time&&$u->timezone?LocalSchedule::utc($campaign->local_wall_time,$u->timezone):($campaign->local_wall_time?null:now());
            DB::table('push_deliveries')->insertOrIgnore(['id'=>(string)Str::uuid(),'campaign_id'=>$campaign->id,'user_id'=>$u->id,'original_due_at'=>$due,'due_at'=>$due,'timezone'=>$u->timezone,'state'=>$due?'pending':'waiting_timezone','created_at'=>now(),'updated_at'=>now()]);
            $this->inbox($u->id,'campaign:'.$campaign->id,$campaign->category,Json::read($campaign->title),Json::read($campaign->body),$target);$count++;
        }
        if(!$count)Json::fail('no_eligible_recipients',409);DB::table('push_campaigns')->where('id',$campaign->id)->update(['state'=>'scheduled','updated_at'=>now()]);return $count;
    }
    public function reschedule(int $uid,string $zone): void {
        foreach(DB::table('push_deliveries')->where('user_id',$uid)->whereIn('state',['pending','waiting_timezone'])->get()as$d){$campaign=DB::table('push_campaigns')->where('id',$d->campaign_id)->first();if(!$campaign||!$campaign->local_wall_time)continue;if($d->due_at&&now()->gte($d->due_at))continue;$due=LocalSchedule::utc($campaign->local_wall_time,$zone);DB::table('push_deliveries')->where('id',$d->id)->update(['timezone'=>$zone,'original_due_at'=>$due,'due_at'=>$due,'state'=>'pending','updated_at'=>now()]);}
    }
    public function decision(object $delivery,object $campaign,object $u): array {
        if($campaign->state==='cancelled'||$u->status!=='active'||now()->gte($campaign->expires_at))return ['suppress','expired_or_cancelled'];
        $prefs=Json::read($u->preferences);if(!($prefs['push']??false))return ['suppress','preference_disabled'];
        if(!DB::table('push_devices')->where('user_id',$u->id)->where('active',true)->where('permission',true)->exists())return ['suppress','no_permitted_device'];
        if($campaign->critical&&$campaign->category==='account_security')return ['send',null];
        if(!$u->timezone)return ['suppress','missing_timezone'];
        if(!$delivery->original_due_at||CarbonImmutable::parse($delivery->original_due_at)->diffInSeconds(now())>21600)return ['suppress','late_more_than_six_hours'];
        $local=now()->setTimezone($u->timezone);if($local->hour>=22||$local->hour<8){$wall=($local->hour>=22?$local->copy()->addDay():$local)->format('Y-m-d').' 08:00';$next=LocalSchedule::utc($wall,$u->timezone);if($next->gt(CarbonImmutable::parse($delivery->original_due_at)->addHours(6))||$next->gte($campaign->expires_at))return ['suppress','quiet_hours_outside_grace'];return ['defer',$next];}
        $recent=DB::table('push_deliveries')->join('push_campaigns','push_campaigns.id','=','push_deliveries.campaign_id')->where('push_deliveries.user_id',$u->id)->where('push_campaigns.critical',false)->whereIn('push_deliveries.state',['sending','sent_to_provider','partial','unknown'])->where('attempted_at','>',now()->subDay())->count();if($recent>=2)return ['suppress','rolling_24h_cap'];
        return ['send',null];
    }
    public function dispatchDue(int $limit=50): array {
        $stats=['sent'=>0,'suppressed'=>0,'deferred'=>0,'failed'=>0];
        foreach(DB::table('push_deliveries')->where('state','pending')->where('due_at','<=',now())->orderBy('due_at')->limit($limit)->get()as$row){
            $claimed=DB::transaction(function()use($row,&$stats){$u=DB::table('users')->where('id',$row->user_id)->lockForUpdate()->first();$d=DB::table('push_deliveries')->where('id',$row->id)->lockForUpdate()->first();$c=DB::table('push_campaigns')->where('id',$d->campaign_id)->first();if(!$u||!$c||$d->state!=='pending')return null;[$action,$reason]=$this->decision($d,$c,$u);
                if($action==='suppress'){DB::table('push_deliveries')->where('id',$d->id)->update(['state'=>'suppressed','reason'=>$reason,'updated_at'=>now()]);$stats['suppressed']++;return null;}
                if($action==='defer'){DB::table('push_deliveries')->where('id',$d->id)->update(['due_at'=>$reason,'reason'=>'quiet_hours','updated_at'=>now()]);$stats['deferred']++;return null;}
                try{$this->fcm->credentials();}catch(\Throwable $e){$stats['failed']++;DB::table('push_deliveries')->where('id',$d->id)->update(['reason'=>'provider_not_configured','due_at'=>now()->addMinutes(5),'updated_at'=>now()]);return null;}
                DB::table('push_deliveries')->where('id',$d->id)->update(['state'=>'sending','attempted_at'=>now(),'updated_at'=>now()]);return [$d,$c,$u];
            },3);
            if(!$claimed)continue;[$d,$c,$u]=$claimed;$accepted=0;$failed=0;$unknown=false;$providerIds=[];
            foreach(DB::table('push_devices')->where('user_id',$u->id)->where('active',true)->where('permission',true)->limit(8)->get()as$device){
                try{$locale=$u->locale==='ar'?'ar':'en';$result=$this->fcm->send(Crypt::decryptString($device->token),['title'=>Json::read($c->title)[$locale],'body'=>Json::read($c->body)[$locale]],['logical_id'=>$c->id,'screen'=>Json::read($c->target)['screen']]);
                    if($result['accepted']){$accepted++;$providerIds[]=$result['name'];}else{$failed++;if(in_array($result['error'],['UNREGISTERED','INVALID_ARGUMENT'],true))DB::table('push_devices')->where('id',$device->id)->update(['active'=>false]);}
                }catch(\Throwable $e){$unknown=true;$failed++;}
            }
            $state=$accepted?($failed?'partial':'sent_to_provider'):($unknown?'unknown':'failed');DB::table('push_deliveries')->where('id',$d->id)->update(['state'=>$state,'reason'=>$unknown?'provider_result_ambiguous_no_automatic_replay':null,'provider_id'=>mb_substr(implode(',',$providerIds),0,255),'updated_at'=>now()]);$accepted?$stats['sent']++:$stats['failed']++;
        }
        // A crashed HTTP send is ambiguous. Never blindly replay and duplicate a remote Push.
        DB::table('push_deliveries')->where('state','sending')->where('attempted_at','<',now()->subMinutes(5))->update(['state'=>'unknown','reason'=>'worker_interrupted_ambiguous','updated_at'=>now()]);
        return $stats;
    }
}
