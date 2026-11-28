<?php
namespace App\Http\Controllers;
use App\Services\Identity;
use App\Support\Json;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\{DB,Hash};
use Illuminate\Support\Str;
final class AuthController extends Controller {
    public function __construct(private Identity $identity){}
    private function device(Request $r): array {return $r->validate(['device_name'=>'sometimes|string|max:100','device_id'=>'sometimes|string|max:128','platform'=>'sometimes|in:android,ios']);}
    private function legal(Request $r): void {if(app()->environment('production')){abort_unless($r->boolean('age_confirmed_13'),422,'13+ age acknowledgement required');$doc=DB::table('legal_documents')->where('slug','terms')->where('approved',true)->whereNotNull('published_at')->first();if(!$doc||!config('puzzlequest.legal_approved'))Json::fail('launch_legal_approval_required',503);}}
    public function guest(Request $r){$this->legal($r);return response()->json($this->identity->guest($this->device($r)),201);}
    /** The public register route does not run the player middleware. Resolve an
     * optional guest bearer credential explicitly so registration retains the
     * same user ID, validated progress and wallet. */
    private function guestForRegistration(Request $r): ?object {
        $plain=$r->bearerToken();
        if($plain===null)return null;
        if($plain==='' || strlen($plain)>256)Json::fail('invalid_guest_session',401);
        $token=DB::table('api_tokens')->where('token_hash',hash('sha256',$plain))->where('expires_at','>',now())->first();
        $user=$token?DB::table('users')->find($token->user_id):null;
        if(!$user || $user->status!=='active')Json::fail('invalid_guest_session',401);
        if(!$user->is_guest)Json::fail('already_registered',409);
        return $user;
    }
    public function register(Request $r){$this->legal($r);$d=$r->validate(['name'=>['required','string','min:2','max:40','regex:/^[\p{Arabic}A-Za-z0-9 _-]+$/u'],'email'=>'required|email:rfc|max:254','password'=>'required|string|min:6|max:64|confirmed','terms_accepted'=>'required|accepted','terms_version'=>'required|string|max:100']);return response()->json($this->identity->register($d+$this->device($r),$this->guestForRegistration($r)),201);}
    public function login(Request $r){$d=$r->validate(['email'=>'required|email:rfc|max:254','password'=>'required|string|max:64']);return response()->json($this->identity->login($d+$this->device($r)));}
    public function otp(Request $r){$d=$r->validate(['email'=>'required|email:rfc|max:254','purpose'=>'required|in:email_verification,password_recovery,mandatory_login']);if($d['purpose']==='mandatory_login'){$u=DB::table('users')->where('email',strtolower($d['email']))->first();if(!$u||$u->password_failures<5)Json::fail('invalid_credentials',401);}return response()->json($this->identity->issueOtp($d['email'],$d['purpose']));}
    public function verify(Request $r){$d=$r->validate(['challenge_id'=>'required|uuid','code'=>'required|string|max:12','purpose'=>'required|in:email_verification,mandatory_login']);$c=$this->identity->consumeOtp($d['challenge_id'],$d['code'],$d['purpose']);$u=DB::table('users')->where('id',$c->user_id)->where('status','active')->first();if(!$u)Json::fail('invalid_credentials',401);DB::table('users')->where('id',$u->id)->update(['email_verified_at'=>now(),'password_failures'=>0,'updated_at'=>now()]);return response()->json($this->identity->token($u->id,$this->device($r)));}
    public function reset(Request $r){$d=$r->validate(['challenge_id'=>'required|uuid','code'=>'required|string|max:12','password'=>'required|string|min:6|max:64|confirmed']);$this->identity->validatePassword($d['password']);$c=$this->identity->consumeOtp($d['challenge_id'],$d['code'],'password_recovery');DB::transaction(function()use($c,$d){DB::table('users')->where('id',$c->user_id)->lockForUpdate()->first();DB::table('users')->where('id',$c->user_id)->update(['password'=>Hash::make($d['password']),'password_failures'=>0,'updated_at'=>now()]);DB::table('api_tokens')->where('user_id',$c->user_id)->delete();DB::table('push_devices')->where('user_id',$c->user_id)->update(['active'=>false]);});return response()->json(['password_reset'=>true,'sign_in_required'=>true]);}
    public function challenge(){ $id=(string)Str::uuid();$nonce=bin2hex(random_bytes(32));DB::table('oauth_challenges')->insert(['id'=>$id,'nonce_hash'=>hash('sha256',$nonce),'expires_at'=>now()->addMinutes(5)]);return response()->json(['challenge_id'=>$id,'nonce'=>$nonce,'expires_in'=>300,'audience'=>config('puzzlequest.google_client_id')]); }
    public function google(Request $r){$this->legal($r);$d=$r->validate(['id_token'=>'required|string|max:12000','challenge_id'=>'required|uuid']);return response()->json($this->identity->google($d+$this->device($r)));}
    public function linkGoogle(Request $r){$this->identity->recent($r->attributes->get('player_token'));$d=$r->validate(['id_token'=>'required|string|max:12000','challenge_id'=>'required|uuid']);return response()->json($this->identity->google($d,$r->attributes->get('player')));}
    public function me(Request $r){return response()->json($this->identity->profile($r->attributes->get('player')->id));}
    public function logout(Request $r){$id=$r->attributes->get('player_token')->id;DB::table('api_tokens')->where('id',$id)->delete();DB::table('push_devices')->where('api_token_id',$id)->update(['active'=>false]);return response()->json(['signed_out'=>true]);}
    public function reauth(Request $r){$d=$r->validate(['password'=>'required|string|max:64']);$u=$r->attributes->get('player');if($u->is_guest||!Hash::check($d['password'],$u->password))Json::fail('invalid_credentials',401);DB::table('api_tokens')->where('id',$r->attributes->get('player_token')->id)->update(['reauth_until'=>now()->addMinutes(10)]);return response()->json(['reauthenticated_until'=>now()->addMinutes(10)->toIso8601String()]);}
    public function reauthRequest(Request $r){$u=$r->attributes->get('player');if($u->is_guest)Json::fail('registration_required',403);return response()->json($this->identity->issueOtp($u->email,'mandatory_login',$u->id));}
    public function reauthVerify(Request $r){$d=$r->validate(['challenge_id'=>'required|uuid','code'=>'required|string|max:12']);$c=$this->identity->consumeOtp($d['challenge_id'],$d['code'],'mandatory_login');if($c->user_id!==$r->attributes->get('player')->id)Json::fail('invalid_credentials',401);DB::table('api_tokens')->where('id',$r->attributes->get('player_token')->id)->update(['reauth_until'=>now()->addMinutes(10)]);return response()->json(['reauthenticated_until'=>now()->addMinutes(10)->toIso8601String()]);}
    public function merge(Request $r){$r->validate(['guest_token'=>'required|string|max:256','confirm'=>'required|accepted']);$u=$r->attributes->get('player');$this->identity->eligible($u);$token=DB::table('api_tokens')->where('token_hash',hash('sha256',$r->input('guest_token')))->where('expires_at','>',now())->first();if(!$token)Json::fail('invalid_guest_token',401);return response()->json($this->identity->merge($token->user_id,$u->id));}
}
