<?php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Support\Facades\DB;

final class StudioToken {
    public function handle($request, Closure $next) {
        $header=(string)$request->header('Authorization','');
        if(!preg_match('/^Bearer ([a-f0-9]{64})$/D',$header,$matches))return response()->json(['error'=>'studio_auth_required'],401);
        $hash=hash('sha256',$matches[1]);
        $token=DB::table('studio_access_tokens')->where('token_hash',$hash)->whereNull('revoked_at')->where('expires_at','>',now())->first();
        if(!$token)return response()->json(['error'=>'studio_token_invalid_or_expired'],401);
        $admin=DB::table('admins')->where('id',$token->admin_id)->where('active',true)->first();
        if(!$admin||!in_array($admin->role,['owner','content'],true))return response()->json(['error'=>'studio_role_not_allowed'],403);
        $request->attributes->set('studio_admin',$admin);
        $request->attributes->set('studio_token_id',$token->id);
        DB::table('studio_access_tokens')->where('id',$token->id)->update(['last_used_at'=>now()]);
        return $next($request);
    }
}
