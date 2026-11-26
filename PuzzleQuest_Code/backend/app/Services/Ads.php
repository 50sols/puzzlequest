<?php
namespace App\Services;
use App\Support\Json;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\{DB,Http,Cache};
use Illuminate\Support\Str;
final class Ads {
    public function __construct(private Wallet $wallet,private Game $game){}
    public static function touchSession(int $uid): void {
        DB::transaction(function()use($uid){DB::table('users')->where('id',$uid)->lockForUpdate()->first();$s=DB::table('ad_sessions')->where('user_id',$uid)->first();
            if(!$s)DB::table('ad_sessions')->insert(['user_id'=>$uid,'session_id'=>(string)Str::uuid(),'started_at'=>now(),'last_activity_at'=>now()]);
            elseif(CarbonImmutable::parse($s->last_activity_at)->diffInSeconds(now())>=1800)DB::table('ad_sessions')->where('user_id',$uid)->update(['session_id'=>(string)Str::uuid(),'started_at'=>now(),'last_activity_at'=>now(),'completions'=>0,'interstitials'=>0,'last_interstitial_at'=>null]);
            else DB::table('ad_sessions')->where('user_id',$uid)->update(['last_activity_at'=>now()]);
        },3);
    }
    public function request(int $uid,string $attempt,string $type): array {
        if(!in_array($type,['hint','full_image'],true))Json::fail('unsupported_ad_reward');$units=config('puzzlequest.ad_units');if(!$units)Json::fail('admob_not_configured',503);
        $a=$this->game->owned($uid,$attempt);if($a->offline||!in_array($a->state,['playing','paused'],true))Json::fail('attempt_not_eligible',409);
        if(DB::table('reward_requests')->where('user_id',$uid)->where('state','pending')->where('expires_at','>',now())->exists())Json::fail('ad_request_pending',409);
        if($type==='hint'){
            if(DB::table('reward_requests')->where('attempt_id',$attempt)->where('type','hint')->where('state','granted')->exists()||DB::table('reward_requests')->where('user_id',$uid)->where('type','hint')->where('state','granted')->where('updated_at','>=',now()->startOfDay())->count()>=3)Json::fail('rewarded_hint_limit',409);
        }else if(DB::table('preview_entitlements')->where('attempt_id',$attempt)->whereIn('state',['granted','active','paused'])->exists())Json::fail('preview_already_available',409);
        $id=(string)Str::uuid();DB::table('reward_requests')->insert(['id'=>$id,'user_id'=>$uid,'attempt_id'=>$attempt,'type'=>$type,'ad_unit'=>$units[0],'expires_at'=>now()->addDay(),'created_at'=>now(),'updated_at'=>now()]);
        return ['reward_request_id'=>$id,'ad_unit'=>$units[0],'ssv'=>['user_id'=>(string)$uid,'custom_data'=>$id],'state'=>'pending','expires_at'=>now()->addDay()->toIso8601String()];
    }
    public function verifyCallback(string $rawQuery): array {
        $position=strrpos($rawQuery,'&signature=');if($position===false)Json::fail('invalid_ssv_signature',400);
        $signed=substr($rawQuery,0,$position);parse_str(substr($rawQuery,$position+1),$tail);parse_str($rawQuery,$query);
        if(!isset($tail['signature'],$tail['key_id'])||count($tail)!==2||!preg_match('/^signature=[^&]+&key_id=[^&]+$/D',substr($rawQuery,$position+1)))Json::fail('invalid_ssv_query',400);
        try{$keys=Cache::remember('admob:ssv:keys',1800,fn()=>Http::timeout(8)->get('https://www.gstatic.com/admob/reward/verifier-keys.json')->throw()->json('keys'));$key=collect($keys)->first(fn($k)=>(string)$k['keyId']===(string)$tail['key_id']);if(!$key)Json::fail('unknown_ssv_key',400);$signature=base64_decode(strtr($tail['signature'],'-_','+/'),true);if(!$signature||openssl_verify($signed,$signature,$key['pem'],OPENSSL_ALGO_SHA256)!==1)Json::fail('invalid_ssv_signature',400);}catch(\Illuminate\Http\Client\ConnectionException $e){Json::fail('ssv_verifier_unavailable',503);}
        foreach(['transaction_id','custom_data','user_id','ad_unit','reward_amount','reward_item','timestamp']as$field)if(!isset($query[$field])||!is_string($query[$field]))Json::fail('invalid_ssv_payload',400);
        if(strlen($query['transaction_id'])>190||!ctype_digit($query['timestamp']))Json::fail('invalid_ssv_payload',400);
        $request=DB::table('reward_requests')->where('id',$query['custom_data'])->first();if(!$request)Json::fail('unknown_reward_request',404);
        return DB::transaction(function()use($request,$query){
            DB::table('users')->where('id',$request->user_id)->lockForUpdate()->first();$r=DB::table('reward_requests')->where('id',$request->id)->lockForUpdate()->first();
            if($r->state==='granted'){if($r->provider_transaction_id!==$query['transaction_id'])Json::fail('ssv_transaction_conflict',409);return ['accepted'=>true,'duplicate'=>true];}
            $u=DB::table('users')->find($r->user_id);if(!$u||$u->status!=='active')Json::fail('reward_identity_unavailable',409);
            $normalize=fn($id)=>str_contains($id,'/')?substr($id,strrpos($id,'/')+1):$id;
            $time=(int)$query['timestamp']/1000;$issued=CarbonImmutable::parse($r->created_at)->getTimestamp();
            if($r->state!=='pending'||now()->gte($r->expires_at)||$query['user_id']!==(string)$r->user_id||$normalize($query['ad_unit'])!==$normalize($r->ad_unit)||$query['reward_amount']!=='1'||$query['reward_item']!==$r->type||$time<$issued-300||$time>now()->getTimestamp()+300)Json::fail('invalid_ssv_binding',400);
            if(DB::table('reward_requests')->where('provider_transaction_id',$query['transaction_id'])->exists())Json::fail('ssv_transaction_reused',409);
            if($r->type==='hint'){
                if(DB::table('reward_requests')->where('attempt_id',$r->attempt_id)->where('type','hint')->where('state','granted')->exists()||DB::table('reward_requests')->where('user_id',$r->user_id)->where('type','hint')->where('state','granted')->where('updated_at','>=',now()->startOfDay())->count()>=3)Json::fail('rewarded_hint_limit',409);
                $this->wallet->change($r->user_id,'ad:'.$r->id,['hints'=>1]);
            }else DB::table('preview_entitlements')->insert(['id'=>(string)Str::uuid(),'user_id'=>$r->user_id,'attempt_id'=>$r->attempt_id,'source'=>'rewarded','remaining_ms'=>10000,'created_at'=>now(),'updated_at'=>now()]);
            DB::table('reward_requests')->where('id',$r->id)->update(['state'=>'granted','provider_transaction_id'=>$query['transaction_id'],'updated_at'=>now()]);return ['accepted'=>true];
        },3);
    }
    public function activate(int $uid,string $attempt,?string $entitlement,string $operation): array {
        $a=$this->game->owned($uid,$attempt);if($a->offline||!in_array($a->state,['playing','paused'],true))Json::fail('attempt_not_eligible',409);
        if(DB::table('preview_entitlements')->where('attempt_id',$attempt)->where('state','active')->exists())Json::fail('preview_overlap',409);
        if($entitlement){$e=DB::table('preview_entitlements')->where('id',$entitlement)->where('user_id',$uid)->where('attempt_id',$attempt)->whereIn('state',['granted','paused'])->lockForUpdate()->first();if(!$e||!$e->remaining_ms)Json::fail('preview_not_available',409);$id=$e->id;}
        else{
            if(DB::table('preview_entitlements')->where('attempt_id',$attempt)->whereIn('state',['granted','paused'])->exists()||DB::table('reward_requests')->where('attempt_id',$attempt)->where('type','full_image')->where('state','pending')->where('expires_at','>',now())->exists())Json::fail('preview_already_pending',409);
            $id=(string)Str::uuid();$this->wallet->change($uid,'preview:'.$operation,['full_image_uses'=>-1]);DB::table('preview_entitlements')->insert(['id'=>$id,'user_id'=>$uid,'attempt_id'=>$attempt,'source'=>'paid','remaining_ms'=>30000,'created_at'=>now(),'updated_at'=>now()]);$e=null;
        }
        // Count assistance at first activation, not on acquisition or a lifecycle resume.
        if(!$e||$e->state==='granted')DB::table('attempts')->where('id',$attempt)->increment('full_images_used');
        DB::table('preview_entitlements')->where('id',$id)->update(['state'=>'active','active_since'=>now(),'updated_at'=>now()]);return (array)DB::table('preview_entitlements')->where('id',$id)->first();
    }
    public function previewTick(int $uid,string $id,int $visibleMs,string $action): array {
        $e=DB::table('preview_entitlements')->where('id',$id)->where('user_id',$uid)->lockForUpdate()->first();if(!$e||$e->state!=='active')Json::fail('preview_not_active',409);
        $wall=max(0,CarbonImmutable::parse($e->active_since)->diffInMilliseconds(now()));if($visibleMs<0||$visibleMs>$wall+2000)Json::fail('invalid_preview_elapsed');
        if(!in_array($action,['tick','pause','close'],true))Json::fail('invalid_preview_action');$left=max(0,$e->remaining_ms-$visibleMs);$state=$action==='close'||$left===0?'ended':($action==='pause'?'paused':'active');
        DB::table('preview_entitlements')->where('id',$id)->update(['remaining_ms'=>$state==='ended'?0:$left,'state'=>$state,'active_since'=>$state==='active'?now():null,'updated_at'=>now()]);return (array)DB::table('preview_entitlements')->where('id',$id)->first();
    }
    public function interstitial(int $uid,string $attempt): array {
        $a=$this->game->owned($uid,$attempt);$s=DB::table('ad_sessions')->where('user_id',$uid)->lockForUpdate()->first();
        $reason=match(true){!$s||$a->state!=='completed'=>'completion_required',$s->completions<2=>'first_completion_excluded',$s->interstitials>=2=>'session_cap',DB::table('interstitial_authorizations')->where('user_id',$uid)->where('created_at','>=',now()->startOfDay())->count()>=6=>'daily_cap',$s->last_interstitial_at&&CarbonImmutable::parse($s->last_interstitial_at)->diffInSeconds(now())<180=>'cooldown',DB::table('interstitial_authorizations')->where('attempt_id',$attempt)->exists()=>'already_authorized',CarbonImmutable::parse($a->completed_at)->lt($s->started_at)=>'different_session',default=>null};
        if($reason)return ['eligible'=>false,'reason'=>$reason];$id=(string)Str::uuid();DB::table('interstitial_authorizations')->insert(['id'=>$id,'user_id'=>$uid,'attempt_id'=>$attempt,'session_id'=>$s->session_id,'created_at'=>now()]);DB::table('ad_sessions')->where('user_id',$uid)->update(['interstitials'=>$s->interstitials+1,'last_interstitial_at'=>now()]);return ['eligible'=>true,'authorization_id'=>$id,'economic_reward'=>false,'expires_in'=>30];
    }
}
