<?php
namespace App\Http\Middleware;
use App\Support\Json;
use Closure;
use Illuminate\Support\Facades\DB;
final class Idempotent {
    public function handle($request, Closure $next) {
        $key=$request->header('Idempotency-Key','');
        if(!preg_match('/^[A-Za-z0-9_.:-]{16,128}$/D',$key)) Json::fail('idempotency_key_required',400);
        $uid=$request->attributes->get('player')->id;
        $hash=hash('sha256',$request->method().'|'.$request->path().'|'.$request->getContent());
        return DB::transaction(function() use($request,$next,$uid,$key,$hash) {
            $actor=DB::table('users')->where('id',$uid)->lockForUpdate()->first();
            if(!$actor || $actor->status!=='active') Json::fail('unauthenticated',401);
            $old=DB::table('operations')->where('user_id',$uid)->where('operation_key',$key)->first();
            if($old) {
                if(!hash_equals($old->request_hash,$hash)) Json::fail('idempotency_key_conflict',409);
                return response()->json(Json::read($old->response),$old->status)->header('Idempotency-Replayed','true');
            }
            $request->attributes->set('operation_key',$key);
            $response=$next($request);
            if($response->getStatusCode()>=200 && $response->getStatusCode()<300) DB::table('operations')->insert(['user_id'=>$uid,'operation_key'=>$key,'request_hash'=>$hash,'response'=>$response->getContent(),'status'=>$response->getStatusCode(),'created_at'=>now()]);
            return $response;
        }, 3);
    }
}
