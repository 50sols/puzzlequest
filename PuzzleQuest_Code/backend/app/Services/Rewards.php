<?php
namespace App\Services;
use App\Support\Json;
use Illuminate\Support\Facades\DB;
final class Rewards {
    public function __construct(private Wallet $wallet){}
    public function shop(int $uid,string $offer,string $operation): array {
        $v=collect(config('puzzlequest.rules.store.offers'))->firstWhere('id',$offer);if(!$v)Json::fail('offer_not_found',404);
        if($v['once_per_player']&&DB::table('claims')->where('user_id',$uid)->where('type','purchase_once')->where('reference',$offer)->exists())Json::fail('already_purchased',409);
        $delta=['coins'=>-(int)$v['price_coins']]+$v['grants'];$result=$this->wallet->change($uid,'purchase:'.$operation,$delta,['offer'=>$offer,'price_coins'=>$v['price_coins'],'grants'=>$v['grants']]);
        if($v['once_per_player'])DB::table('claims')->insert(['user_id'=>$uid,'type'=>'purchase_once','reference'=>$offer,'created_at'=>now()]);return ['wallet'=>$result,'offer'=>$offer];
    }
    public function daily(int $uid,bool $claim=false): array {
        $history=DB::table('claims')->where('user_id',$uid)->where('type','daily')->orderByDesc('id');$last=$history->first();$claimedToday=$history->clone()->where('reference',now()->toDateString())->exists();$next=$last?(Json::read($last->payload)['day']%7)+1:1;
        if($claim){if($claimedToday)Json::fail('already_claimed_today',409);$reward=config('puzzlequest.rules.daily_reward.days')[$next-1];$this->wallet->change($uid,'daily:'.now()->toDateString(),['coins'=>(int)$reward['coins'],'hints'=>(int)$reward['hints']]);DB::table('claims')->insert(['user_id'=>$uid,'type'=>'daily','reference'=>now()->toDateString(),'payload'=>Json::encode(['day'=>$next]),'created_at'=>now()]);$claimedToday=true;}
        return ['claimed_today'=>$claimedToday,'next_day'=>$next,'calendar'=>config('puzzlequest.rules.daily_reward.days'),'next_reset_at'=>now()->addDay()->startOfDay()->toIso8601String(),'wallet'=>$this->wallet->balance($uid)];
    }
    public function missions(int $uid): array {
        $rows=[];foreach(['daily'=>now()->startOfDay(),'weekly'=>now()->startOfWeek(\Carbon\CarbonInterface::MONDAY)]as$period=>$start){$successes=DB::table('attempts')->where('user_id',$uid)->where('state','completed')->where('completed_at','>=',$start)->get();$pieces=DB::table('game_events')->where('user_id',$uid)->where('type','piece_placed')->where('created_at','>=',$start)->count();foreach(config('puzzlequest.rules.missions.'.$period)as$m){$progress=match($m['type']){'successful_attempts'=>$successes->count(),'unique_correct_piece_placements'=>$pieces,'successful_attempt_without_any_used_assistance'=>$successes->filter(fn($a)=>$a->hints_used+$a->shuffles_used+$a->full_images_used===0)->count(),default=>0};$ref=$m['id'].':'.$start->toDateString();$rows[]=$m+['period'=>$period,'cycle'=>$start->toDateString(),'progress'=>$progress,'eligible'=>$progress>=$m['target'],'claimed'=>DB::table('claims')->where('user_id',$uid)->where('type','mission')->where('reference',$ref)->exists()];}}
        return $rows;
    }
    public function mission(int $uid,string $id): array {
        $m=collect($this->missions($uid))->firstWhere('id',$id);if(!$m||!$m['eligible'])Json::fail('mission_not_eligible',409);if($m['claimed'])Json::fail('mission_already_claimed',409);$ref=$id.':'.$m['cycle'];$w=$this->wallet->change($uid,'mission:'.$ref,['coins'=>(int)$m['reward_coins']]);DB::table('claims')->insert(['user_id'=>$uid,'type'=>'mission','reference'=>$ref,'created_at'=>now()]);return ['wallet'=>$w];
    }
    public function chest(int $uid): array {
        $rule=config('puzzlequest.rules.collections.reward_chest');$progress=DB::table('progress')->where('user_id',$uid)->whereIn('level_id',$rule['eligible_only_if']['all_level_ids_completed'])->get();if($progress->count()!==5||$progress->sum('best_stars')<10)Json::fail('chest_not_eligible',409);if(DB::table('claims')->where('user_id',$uid)->where('type','chest')->where('reference',$rule['id'])->exists())Json::fail('chest_already_claimed',409);$w=$this->wallet->change($uid,'chest:'.$rule['id'],['coins'=>300,'hints'=>2]);DB::table('claims')->insert(['user_id'=>$uid,'type'=>'chest','reference'=>$rule['id'],'created_at'=>now()]);return ['wallet'=>$w];
    }
    public function upgrade(int $uid,string $building,int $expectedStage): array {
        $rules=config('puzzlequest.rules.village.buildings.'.$building);if(!$rules)Json::fail('building_not_found',404);
        DB::table('player_buildings')->insertOrIgnore(['user_id'=>$uid,'building_id'=>$building,'stage'=>0,'created_at'=>now(),'updated_at'=>now()]);$b=DB::table('player_buildings')->where('user_id',$uid)->where('building_id',$building)->lockForUpdate()->first();if($b->stage!==$expectedStage)Json::fail('building_stage_changed',409);$transition=collect($rules['transitions'])->firstWhere('from_stage',$b->stage);if(!$transition)Json::fail('building_fully_upgraded',409);$level=DB::table('levels')->where('display_code',$transition['requires_level_completed'])->first();if(!$level||!DB::table('progress')->where('user_id',$uid)->where('level_id',$level->id)->exists())Json::fail('building_goal_not_met',409);
        $wallet=$this->wallet->change($uid,'building:'.$building.':'.$transition['to_stage'],['coins'=>-(int)$transition['price_coins']]);DB::table('player_buildings')->where('id',$b->id)->update(['stage'=>$transition['to_stage'],'updated_at'=>now()]);return ['building'=>$building,'stage'=>$transition['to_stage'],'wallet'=>$wallet];
    }
}
