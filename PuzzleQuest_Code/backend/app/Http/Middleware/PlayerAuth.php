<?php
namespace App\Http\Middleware;
use App\Support\Json;
use Closure;
use Illuminate\Support\Facades\DB;
final class PlayerAuth {
    public function handle($request, Closure $next) {
        $plain=$request->bearerToken();
        if (!$plain || strlen($plain)>256) Json::fail('unauthenticated',401);
        $token=DB::table('api_tokens')->where('token_hash',hash('sha256',$plain))->where('expires_at','>',now())->first();
        $user=$token ? DB::table('users')->find($token->user_id) : null;
        if (!$user || $user->status!=='active') Json::fail('unauthenticated',401);
        $request->attributes->set('player',$user); $request->attributes->set('player_token',$token);
        DB::table('api_tokens')->where('id',$token->id)->update(['last_activity_at'=>now()]);
        \App\Services\Ads::touchSession($user->id);
        return $next($request);
    }
}
