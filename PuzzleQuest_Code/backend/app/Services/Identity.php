<?php
namespace App\Services;
use App\Support\Json;
use Firebase\JWT\JWT;
use Firebase\JWT\JWK;
use Illuminate\Support\Facades\{DB,Hash,Mail,Cache,Http,RateLimiter,Validator};
use Illuminate\Support\Str;

final class Identity {
    public function __construct(private Wallet $wallet) {}
    public function profile(int $uid): array {
        $u=DB::table('users')->find($uid); if(!$u)Json::fail('unauthenticated',401);
        return ['id'=>$u->id,'name'=>$u->name,'email'=>$u->is_guest?null:$u->email,'is_guest'=>(bool)$u->is_guest,'email_verified'=>(bool)$u->email_verified_at,'avatar'=>$u->avatar,'visibility'=>$u->visibility,'locale'=>$u->locale,'timezone'=>$u->timezone,'preferred_world'=>$u->preferred_world,'preferences'=>Json::read($u->preferences),'wallet'=>$this->wallet->balance($uid),'stars'=>(int)DB::table('progress')->where('user_id',$uid)->sum('best_stars')];
    }
    public function eligible(object $u): void { if(!$u->is_guest&&!$u->email_verified_at)Json::fail('email_verification_required',403,['local_provisional_play_allowed'=>true]); }
    public function token(int $uid,array $device): array {
        $plain=bin2hex(random_bytes(32));$id=(string)Str::uuid();
        DB::table('api_tokens')->insert(['id'=>$id,'user_id'=>$uid,'token_hash'=>hash('sha256',$plain),'device_name'=>$device['device_name']??'Mobile','platform'=>$device['platform']??'android','device_id'=>$device['device_id']??(string)Str::uuid(),'last_activity_at'=>now(),'created_at'=>now(),'expires_at'=>now()->addDays(30),'reauth_until'=>now()->addMinutes(10)]);
        return ['access_token'=>$plain,'token_type'=>'Bearer','expires_in'=>2592000,'player'=>$this->profile($uid)];
    }
    public function guest(array $device): array {
        return DB::transaction(function()use($device){$uid=DB::table('users')->insertGetId(['name'=>'Guest','email'=>Str::uuid().'@guest.invalid','password'=>Hash::make(Str::random(64)),'is_guest'=>true,'preferences'=>Json::encode(['push'=>false,'sound'=>true,'music'=>true]),'created_at'=>now(),'updated_at'=>now()]);$this->wallet->initial($uid);return $this->token($uid,$device);});
    }
    public function validatePassword(string $password): void {
        if(mb_strlen($password)<6||mb_strlen($password)>64||in_array(strtolower($password),['123456','12345678','password','qwerty','abc123','111111','000000','password123'],true))Json::fail('weak_password');
        $sha=strtoupper(sha1($password));
        try{$range=Http::timeout(6)->withHeaders(['Add-Padding'=>'true'])->get('https://api.pwnedpasswords.com/range/'.substr($sha,0,5))->throw()->body();}
        catch(\Throwable $e){Json::fail('password_safety_service_unavailable',503);}
        foreach(explode("\n",$range)as$line){$parts=explode(':',trim($line));if(count($parts)===2&&hash_equals(substr($sha,5),$parts[0])&&(int)$parts[1]>0)Json::fail('compromised_password');}
    }
    public function register(array $data,?object $guest=null): array {
        $this->validatePassword($data['password']);
        return DB::transaction(function()use($data,$guest){
            $email=strtolower(trim($data['email']));if(str_ends_with($email,'@guest.invalid'))Json::fail('invalid_email');
            if(DB::table('users')->where('email',$email)->exists())Json::fail('email_unavailable_use_login_or_recovery',409);
            $values=['name'=>$data['name'],'email'=>$email,'password'=>Hash::make($data['password']),'is_guest'=>false,'updated_at'=>now()];
            if($guest){$u=DB::table('users')->where('id',$guest->id)->lockForUpdate()->first();if(!$u||!$u->is_guest||$u->status!=='active')Json::fail('invalid_guest_session',409);DB::table('users')->where('id',$u->id)->update($values);$uid=$u->id;DB::table('api_tokens')->where('user_id',$uid)->delete();DB::table('push_devices')->where('user_id',$uid)->update(['active'=>false]);}
            else{$uid=DB::table('users')->insertGetId($values+['created_at'=>now()]);$this->wallet->initial($uid);}
            DB::table('consents')->insert(['user_id'=>$uid,'document_version'=>$data['terms_version'],'choices'=>Json::encode(['terms_accepted'=>true,'personalized_ads'=>false,'tracking'=>false,'marketing'=>false]),'created_at'=>now()]);
            $result=$this->token($uid,$data);try{$result['verification']=$this->issueOtp($email,'email_verification');}catch(\Illuminate\Http\Exceptions\HttpResponseException $e){$result['verification']=['state'=>'delivery_unavailable_retry_after_setup'];}
            return $result;
        });
    }
    public function login(array $data): array {
        $email=strtolower($data['email']);$key='login:'.hash('sha256',$email.'|'.request()->ip());
        if(RateLimiter::tooManyAttempts($key,10))Json::fail('try_later',429);
        RateLimiter::hit($key,900);$u=DB::table('users')->where('email',$email)->where('is_guest',false)->where('status','active')->first();
        if(!$u||!Hash::check($data['password'],$u->password)){if($u)DB::table('users')->where('id',$u->id)->increment('password_failures');Json::fail('invalid_credentials',401);}
        if($u->password_failures>=5)return ['state'=>'mandatory_email_otp','challenge'=>$this->issueOtp($email,'mandatory_login')];
        RateLimiter::clear($key);return $this->token($u->id,$data);
    }
    public function issueOtp(string $email,string $purpose,?int $uid=null): array {
        if(!in_array($purpose,['email_verification','password_recovery','mandatory_login','email_change','account_recovery','support_recovery'],true))Json::fail('invalid_otp_purpose');
        $email=strtolower($email);$key=hash('sha256',$email.'|'.$purpose);
        foreach([['otp:minute:',1,60],['otp:15m:',3,900],['otp:day:',10,86400]]as[$prefix,$limit,$seconds]){if(RateLimiter::tooManyAttempts($prefix.$key,$limit))Json::fail('otp_rate_limited',429);}
        if(RateLimiter::tooManyAttempts('otp:verify:'.$key,5))Json::fail('otp_temporarily_blocked',429);
        $user=$uid?DB::table('users')->find($uid):DB::table('users')->where('email',$email)->where('is_guest',false)->first();
        DB::table('otp_challenges')->where('email',$email)->where('purpose',$purpose)->whereNull('consumed_at')->update(['consumed_at'=>now()]);
        $id=(string)Str::uuid();$code=(string)random_int(100000,999999);
        DB::table('otp_challenges')->insert(['id'=>$id,'user_id'=>$user?->id,'email'=>$email,'purpose'=>$purpose,'code_hash'=>hash_hmac('sha256',$code,config('app.key')),'expires_at'=>now()->addSeconds(600),'created_at'=>now()]);
        foreach([['otp:minute:',60],['otp:15m:',900],['otp:day:',86400]]as[$prefix,$seconds])RateLimiter::hit($prefix.$key,$seconds);
        if($user){
            if(app()->environment('production')&&in_array(config('mail.default'),['log','array'],true))Json::fail('email_transport_not_configured',503);
            try{Mail::raw("PuzzleQuest verification code: {$code}\nExpires in 10 minutes. Do not share this code.",fn($m)=>$m->to($email)->subject('PuzzleQuest verification code'));}catch(\Throwable $e){Json::fail('email_delivery_unavailable',503);}
        }
        return ['challenge_id'=>$id,'expires_in'=>600,'resend_after'=>60,'state'=>'if_account_exists_code_sent'];
    }
    public function consumeOtp(string $id,string $code,string $purpose): object {
        $code=strtr($code,['٠'=>'0','١'=>'1','٢'=>'2','٣'=>'3','٤'=>'4','٥'=>'5','٦'=>'6','٧'=>'7','٨'=>'8','٩'=>'9','۰'=>'0','۱'=>'1','۲'=>'2','۳'=>'3','۴'=>'4','۵'=>'5','۶'=>'6','۷'=>'7','۸'=>'8','۹'=>'9']);
        $result=DB::transaction(function()use($id,$code,$purpose){$c=DB::table('otp_challenges')->where('id',$id)->lockForUpdate()->first();
            if(!$c||$c->purpose!==$purpose||$c->consumed_at||now()->gte($c->expires_at)||$c->attempts>=5)return null;
            $key=hash('sha256',$c->email.'|'.$purpose);$correct=preg_match('/^\d{6}$/D',$code)&&hash_equals($c->code_hash,hash_hmac('sha256',$code,config('app.key')));
            DB::table('otp_challenges')->where('id',$id)->update(['attempts'=>$c->attempts+1,'consumed_at'=>($correct||$c->attempts+1>=5)?now():null]);
            if(!$correct){RateLimiter::hit('otp:verify:'.$key,900);return null;}return $c;
        });
        if(!$result||!$result->user_id)Json::fail('invalid_or_expired_code',422);
        return $result;
    }
    public function google(array $data,?object $linkTo=null): array {
        try {
            $keys=Cache::remember('google:identity:jwks',1800,fn()=>Http::timeout(8)->get('https://www.googleapis.com/oauth2/v3/certs')->throw()->json());
            $payload=(array)JWT::decode($data['id_token'],JWK::parseKeySet($keys));
        }catch(\Throwable $e){Json::fail('invalid_google_token',401);}
        if(!in_array($payload['iss']??'',['accounts.google.com','https://accounts.google.com'],true)||($payload['aud']??null)!==config('puzzlequest.google_client_id')||empty($payload['sub'])||empty($payload['email_verified'])||empty($payload['email']))Json::fail('invalid_google_identity',401);
        return DB::transaction(function()use($payload,$data,$linkTo){
            $c=DB::table('oauth_challenges')->where('id',$data['challenge_id'])->lockForUpdate()->first();
            if(!$c||$c->used_at||now()->gte($c->expires_at)||!hash_equals($c->nonce_hash,hash('sha256',$payload['nonce']??'')))Json::fail('invalid_google_nonce',401);
            DB::table('oauth_challenges')->where('id',$c->id)->update(['used_at'=>now()]);
            if($linkTo){
                if($linkTo->is_guest||!$linkTo->email_verified_at||strtolower($payload['email'])!==$linkTo->email)Json::fail('google_link_requires_matching_verified_email',409);
                if(DB::table('users')->where('google_sub',$payload['sub'])->where('id','!=',$linkTo->id)->exists())Json::fail('google_identity_already_linked',409);
                DB::table('users')->where('id',$linkTo->id)->update(['google_sub'=>$payload['sub'],'updated_at'=>now()]);return ['google_linked'=>true];
            }
            $u=DB::table('users')->where('google_sub',$payload['sub'])->where('status','active')->lockForUpdate()->first();
            if(!$u){$email=strtolower($payload['email']);if(DB::table('users')->where('email',$email)->exists())Json::fail('account_exists_reauthenticate_to_link_google',409);
                $uid=DB::table('users')->insertGetId(['name'=>mb_substr($payload['name']??'Player',0,40),'email'=>$email,'password'=>Hash::make(Str::random(64)),'google_sub'=>$payload['sub'],'email_verified_at'=>now(),'created_at'=>now(),'updated_at'=>now()]);$this->wallet->initial($uid);
            }else $uid=$u->id;
            return $this->token($uid,$data);
        });
    }
    public function recent(object $token): void { if(!$token->reauth_until||now()->gte($token->reauth_until))Json::fail('recent_authentication_required',403); }
    public function merge(int $guestId,int $targetId): array {
        if($guestId===$targetId)Json::fail('invalid_merge');
        return DB::transaction(function()use($guestId,$targetId){$users=DB::table('users')->whereIn('id',[$guestId,$targetId])->orderBy('id')->lockForUpdate()->get()->keyBy('id');$g=$users[$guestId]??null;$u=$users[$targetId]??null;
            if(!$g||!$u||!$g->is_guest||$u->is_guest||!$u->email_verified_at||$g->status!=='active'||$u->status!=='active')Json::fail('merge_not_eligible',409);
            $known=[];foreach(DB::table('wallet_lots')->where('user_id',$targetId)->get()as$l)$known=array_merge($known,Json::read($l->origins));
            foreach(DB::table('wallet_lots')->where('user_id',$guestId)->where('remaining','>',0)->lockForUpdate()->get()as$l){$origins=Json::read($l->origins);if($l->transferable&&!array_intersect($origins,$known))$this->wallet->change($targetId,'merge-lot:'.$guestId.':'.$l->id,[$l->resource=>(int)$l->remaining],['source_guest'=>$guestId],true,$origins);}
            foreach(DB::table('progress')->where('user_id',$guestId)->get()as$gProgress){$existing=DB::table('progress')->where('user_id',$targetId)->where('level_id',$gProgress->level_id)->first();if($existing)DB::table('progress')->where('id',$existing->id)->update(['best_stars'=>max($existing->best_stars,$gProgress->best_stars),'best_elapsed_ms'=>min($existing->best_elapsed_ms,$gProgress->best_elapsed_ms),'updated_at'=>now()]);else{unset($gProgress->id);$gProgress->user_id=$targetId;DB::table('progress')->insert((array)$gProgress);}}
            foreach(DB::table('claims')->where('user_id',$guestId)->get()as$c)DB::table('claims')->insertOrIgnore(['user_id'=>$targetId,'type'=>$c->type,'reference'=>$c->reference,'payload'=>$c->payload,'created_at'=>$c->created_at]);
            DB::table('attempts')->where('user_id',$guestId)->where('state','completed')->update(['user_id'=>$targetId,'rank_verified'=>false]);
            DB::table('api_tokens')->where('user_id',$guestId)->delete();DB::table('push_devices')->where('user_id',$guestId)->update(['active'=>false]);
            DB::table('users')->where('id',$guestId)->update(['status'=>'merged','merged_into'=>$targetId,'updated_at'=>now()]);
            return $this->profile($targetId);
        },3);
    }
}
