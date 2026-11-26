<?php
namespace App\Services;
use App\Support\Json;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
final class Wallet {
    public const RESOURCES=['coins','hints','shuffle_uses','full_image_uses'];
    public function balance(int $uid): array { $w=DB::table('wallets')->where('user_id',$uid)->first(); return array_intersect_key((array)$w,array_flip(self::RESOURCES)); }
    public function change(int $uid,string $reference,array $delta,array $metadata=[],bool $transferable=true,?array $origins=null): array {
        return DB::transaction(function()use($uid,$reference,$delta,$metadata,$transferable,$origins){
            DB::table('users')->where('id',$uid)->lockForUpdate()->first();
            $existing=DB::table('ledger')->where('user_id',$uid)->where('reference',$reference)->first();
            if($existing)return Json::read($existing->balance);
            $w=DB::table('wallets')->where('user_id',$uid)->lockForUpdate()->first();
            if(!$w) { DB::table('wallets')->insert(['user_id'=>$uid,'created_at'=>now(),'updated_at'=>now()]); $w=DB::table('wallets')->where('user_id',$uid)->first(); }
            $balance=$this->balance($uid); $spentOrigins=[]; $paidTransferable=true;
            foreach($delta as $resource=>$amount){
                if(!in_array($resource,self::RESOURCES,true)||!is_int($amount))Json::fail('invalid_wallet_delta');
                if($balance[$resource]+$amount<0)Json::fail('insufficient_balance',409,['resource'=>$resource,'available'=>$balance[$resource],'required'=>-$amount]);
                if($amount<0){$need=-$amount; foreach(DB::table('wallet_lots')->where('user_id',$uid)->where('resource',$resource)->where('remaining','>',0)->orderBy('id')->lockForUpdate()->get() as $lot){$use=min($need,$lot->remaining);$need-=$use;$spentOrigins=array_merge($spentOrigins,Json::read($lot->origins));if(!$lot->transferable)$paidTransferable=false; DB::table('wallet_lots')->where('id',$lot->id)->update(['remaining'=>$lot->remaining-$use,'updated_at'=>now()]);if(!$need)break;}if($need)throw new \LogicException('Wallet/lot invariant violated');}
                $balance[$resource]+=$amount;
            }
            $creditOrigins=$origins ?? ($spentOrigins ? array_values(array_unique($spentOrigins)) : [$reference]);
            foreach($delta as $resource=>$amount)if($amount>0)DB::table('wallet_lots')->insert(['user_id'=>$uid,'resource'=>$resource,'remaining'=>$amount,'origins'=>Json::encode($creditOrigins),'transferable'=>$transferable&&$paidTransferable,'created_at'=>now(),'updated_at'=>now()]);
            DB::table('wallets')->where('user_id',$uid)->update($balance+['updated_at'=>now()]);
            DB::table('ledger')->insert(['id'=>(string)Str::uuid(),'user_id'=>$uid,'reference'=>$reference,'delta'=>Json::encode($delta),'balance'=>Json::encode($balance),'metadata'=>Json::encode($metadata+['spent_origins'=>array_values(array_unique($spentOrigins)),'spent_transferable'=>$paidTransferable]),'created_at'=>now()]);
            return $balance;
        },3);
    }
    public function initial(int $uid): array { return $this->change($uid,'initial',['coins'=>300,'hints'=>2],[],false); }
}
