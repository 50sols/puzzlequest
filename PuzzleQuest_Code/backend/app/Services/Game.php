<?php
namespace App\Services;
use App\Support\Json;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class Game {
    public function __construct(private Wallet $wallet,private Identity $identity){}
    public function unlocked(int $uid,object $level): bool {
        $world=DB::table('worlds')->where('id',$level->world_id)->first();
        if(!$level->published||!$level->active_revision_id||!$world?->published)return false;
        $earlier=DB::table('worlds')->where('position','<',$world->position)->orderBy('position')->get();
        foreach($earlier as$w){$required=DB::table('levels')->where('world_id',$w->id)->where('published',true)->pluck('id');if(!$w->published||$required->isEmpty()||DB::table('progress')->where('user_id',$uid)->whereIn('level_id',$required)->count()!==$required->count())return false;}
        return !$level->previous_level_id||DB::table('progress')->where('user_id',$uid)->where('level_id',$level->previous_level_id)->where('best_stars','>=',1)->exists();
    }
    public function catalog(?int $uid): array {
        $worlds=DB::table('worlds')->orderBy('position')->get()->map(fn($w)=>['id'=>$w->id,'title'=>Json::read($w->title),'published'=>(bool)$w->published]);
        $levels=[];foreach(DB::table('levels')->where('published',true)->orderBy('world_id')->orderBy('position')->get()as$l){$rev=DB::table('content_revisions')->where('id',$l->active_revision_id)->first();if(!$rev)continue;$v=Json::read($rev->payload);$hashes=$v['hashes'];$files=[];foreach($hashes as$f=>$hash)$files[$f]=['url'=>url($v['asset_prefix'].'/'.$f),'sha256'=>$hash];$levels[]=['id'=>$l->id,'world_id'=>$l->world_id,'display_code'=>$l->display_code,'position'=>$l->position,'title'=>Json::read($l->title),'revision'=>$rev->revision,'revision_id'=>$rev->id,'piece_count'=>$v['piece_count'],'level_time_limit_seconds'=>$v['level_time_limit_seconds'],'three_star_seconds'=>$v['three_star_seconds'],'two_star_seconds'=>$v['two_star_seconds'],'schema_version'=>1,'assets'=>$files,'unlocked'=>$uid?$this->unlocked($uid,$l):false];}
        $catalog=['schema_version'=>1,'worlds'=>$worlds,'levels'=>$levels,'generated_at'=>now()->toIso8601String(),'studio_content'=>app(\App\Services\StudioDocuments::class)->publicCatalog()['items']];
        $bytes=Json::encode($catalog);$key=config('puzzlequest.catalog_signing_key');
        return ['catalog'=>$catalog,'canonical_base64'=>base64_encode($bytes),'sha256'=>hash('sha256',$bytes),'signature'=>$key?base64_encode(sodium_crypto_sign_detached($bytes,base64_decode($key))):null,'signature_algorithm'=>$key?'Ed25519':null,'public_key'=>$key?base64_encode(sodium_crypto_sign_publickey_from_secretkey(base64_decode($key))):null];
    }
    public function start(object $user,string $levelId,bool $offline=false): array {
        $this->identity->eligible($user);$l=DB::table('levels')->where('id',$levelId)->first();if(!$l||!$this->unlocked($user->id,$l))Json::fail('level_locked',403);
        $rev=DB::table('content_revisions')->where('id',$l->active_revision_id)->first();$snapshot=Json::read($rev->payload);$id=(string)Str::uuid();
        DB::table('attempts')->insert(['id'=>$id,'user_id'=>$user->id,'level_id'=>$l->id,'revision_id'=>$rev->id,'snapshot'=>Json::encode($snapshot),'placed'=>'[]','offline'=>$offline,'active_since'=>$offline?null:now(),'ticket_expires_at'=>$offline?now()->addDay():null,'created_at'=>now(),'updated_at'=>now()]);
        return $this->view($user->id,$id);
    }
    public function owned(int $uid,string $id): object { $a=DB::table('attempts')->where('id',$id)->where('user_id',$uid)->lockForUpdate()->first();if(!$a)Json::fail('attempt_not_found',404);return $a; }
    public function elapsed(object $a): int { return (int)$a->elapsed_ms+($a->active_since?(int)max(0,CarbonImmutable::parse($a->active_since)->diffInMilliseconds(now())):0); }
    public function view(int $uid,string $id): array {
        $a=$this->owned($uid,$id);$v=Json::read($a->snapshot);$elapsed=$this->elapsed($a);return ['id'=>$a->id,'level_id'=>$a->level_id,'revision_id'=>$a->revision_id,'state'=>($a->state==='playing'&&$elapsed>=$v['level_time_limit_seconds']*1000)?'timed_out':$a->state,'offline'=>(bool)$a->offline,'placed_piece_ids'=>Json::read($a->placed),'elapsed_ms'=>$elapsed,'remaining_ms'=>max(0,$v['level_time_limit_seconds']*1000-$elapsed),'hints_used'=>$a->hints_used,'shuffles_used'=>$a->shuffles_used,'full_image_uses'=>$a->full_images_used,'rating'=>$a->rating,'score'=>$a->score,'rank_verified'=>(bool)$a->rank_verified,'ticket_expires_at'=>$a->ticket_expires_at,'wallet'=>$this->wallet->balance($uid)];
    }
    public function clock(int $uid,string $id,string $action): array {
        $a=$this->owned($uid,$id);if($a->offline||!in_array($a->state,['playing','paused','ad_playing'],true))Json::fail('invalid_attempt_state',409);
        $elapsed=$this->elapsed($a);$v=Json::read($a->snapshot);if($elapsed>=$v['level_time_limit_seconds']*1000){DB::table('attempts')->where('id',$id)->update(['state'=>'timed_out','elapsed_ms'=>$elapsed,'active_since'=>null,'updated_at'=>now()]);return $this->view($uid,$id);}
        if($action==='resume'){if($a->state==='playing')return $this->view($uid,$id);$state='playing';$active=now();}
        elseif($action==='pause'){$state='paused';$active=null;}
        elseif($action==='ad-start'){
            if(!DB::table('reward_requests')->where('attempt_id',$id)->where('state','pending')->where('expires_at','>',now())->exists())Json::fail('no_pending_ad',409);$state='ad_playing';$active=null;
        }else Json::fail('invalid_clock_action');
        DB::table('attempts')->where('id',$id)->update(['state'=>$state,'elapsed_ms'=>$elapsed,'active_since'=>$active,'updated_at'=>now()]);return $this->view($uid,$id);
    }
    public function eventBatch(int $uid,string $id,array $events): array {
        $a=$this->owned($uid,$id);if($a->offline||$a->state!=='playing')Json::fail('attempt_not_playing',409);
        $snapshot=Json::read($a->snapshot);$elapsed=$this->elapsed($a);
        if($elapsed>=$snapshot['level_time_limit_seconds']*1000){DB::table('attempts')->where('id',$id)->update(['state'=>'timed_out','elapsed_ms'=>$elapsed,'active_since'=>null,'updated_at'=>now()]);return $this->view($uid,$id);}
        $this->place($a,$events);
        if(count(Json::read(DB::table('attempts')->where('id',$id)->value('placed')))===$snapshot['piece_count'])$this->finish($uid,$id,$elapsed,true);
        return $this->view($uid,$id);
    }
    private function place(object $a,array $events): void {
        $v=Json::read($a->snapshot);$known=collect($v['manifest']['pieces'])->keyBy('id');$placed=Json::read($a->placed);
        foreach($events as$event){$piece=$known[$event['piece_id']]??null;if(!$piece)Json::fail('unknown_piece');$anchor=$event['anchor'];$distance=hypot($anchor[0]-$piece['snap_anchor_px'][0],$anchor[1]-$piece['snap_anchor_px'][1]);if($distance>$v['manifest']['snap_threshold_board_px'])Json::fail('invalid_snap');
            $prior=DB::table('game_events')->where('id',$event['event_id'])->first();if($prior){if($prior->user_id!==$a->user_id||$prior->attempt_id!==$a->id||$prior->piece_id!==$event['piece_id'])Json::fail('event_id_conflict',409);continue;}
            if(in_array($event['piece_id'],$placed,true))continue;
            DB::table('game_events')->insert(['id'=>$event['event_id'],'user_id'=>$a->user_id,'attempt_id'=>$a->id,'type'=>'piece_placed','piece_id'=>$event['piece_id'],'payload'=>Json::encode($event),'created_at'=>now()]);$placed[]=$event['piece_id'];
        }
        DB::table('attempts')->where('id',$a->id)->update(['placed'=>Json::encode($placed),'updated_at'=>now()]);
    }
    public function finish(int $uid,string $id,int $elapsed,bool $verified): void {
        $a=$this->owned($uid,$id);if($a->state==='completed')return;$v=Json::read($a->snapshot);$helps=$a->hints_used+$a->shuffles_used+$a->full_images_used;
        if($elapsed>=$v['level_time_limit_seconds']*1000)Json::fail('attempt_timed_out',409);
        $rating=$elapsed<=$v['three_star_seconds']*1000&&$helps===0?3:($elapsed<=$v['two_star_seconds']*1000&&$helps<=1?2:1);
        $score=(int)max(0,min(1500,1000+floor(500*max(0,1-$elapsed/($v['level_time_limit_seconds']*1000)))-100*$helps));
        DB::table('attempts')->where('id',$id)->update(['state'=>'completed','elapsed_ms'=>$elapsed,'active_since'=>null,'rating'=>$rating,'score'=>$score,'completed_at'=>now(),'rank_verified'=>$verified,'updated_at'=>now()]);
        DB::table('ad_sessions')->where('user_id',$uid)->increment('completions');
        $progress=DB::table('progress')->where('user_id',$uid)->where('level_id',$a->level_id)->lockForUpdate()->first();
        if($progress)DB::table('progress')->where('id',$progress->id)->update(['best_stars'=>max($progress->best_stars,$rating),'best_elapsed_ms'=>min($progress->best_elapsed_ms,$elapsed),'updated_at'=>now()]);
        else DB::table('progress')->insert(['user_id'=>$uid,'level_id'=>$a->level_id,'best_stars'=>$rating,'best_elapsed_ms'=>$elapsed,'first_completed_at'=>now(),'created_at'=>now(),'updated_at'=>now()]);
        $this->wallet->change($uid,'first:'.$a->level_id,['coins'=>500],['attempt_id'=>$id]);
        $this->awardBadges($uid);
    }
    public function assist(int $uid,string $id,string $type,bool $buy,string $operation): array {
        $a=$this->owned($uid,$id);$v=Json::read($a->snapshot);if($a->offline||!in_array($a->state,['playing','paused'],true)||$this->elapsed($a)>=$v['level_time_limit_seconds']*1000)Json::fail('attempt_not_eligible',409);
        $remaining=array_values(array_diff(array_column($v['manifest']['pieces'],'id'),Json::read($a->placed)));
        if($type==='shuffle'&&count($remaining)<2)Json::fail('not_enough_unplaced_pieces',409);
        if($type==='hint'&&!$remaining)Json::fail('no_unplaced_piece',409);
        if($type==='shuffle'){
            if($a->state!=='paused')Json::fail('shuffle_requires_pause',409);
            $price=(int)collect(config('puzzlequest.rules.store.offers'))->firstWhere('id','shuffle_pack')['price_coins'];
            $balance=$this->wallet->balance($uid);if($balance['shuffle_uses']>0)$this->wallet->change($uid,'shuffle:'.$operation,['shuffle_uses'=>-1]);elseif($buy)$this->wallet->change($uid,'shuffle-buy:'.$operation,['coins'=>-$price]);else Json::fail('shuffle_confirmation_required',409,['price_coins'=>$price]);
            shuffle($remaining);DB::table('attempts')->where('id',$id)->increment('shuffles_used');return ['tray_order'=>$remaining,'wallet'=>$this->wallet->balance($uid)];
        }
        if($type==='hint'){$this->wallet->change($uid,'hint:'.$operation,['hints'=>-1]);DB::table('attempts')->where('id',$id)->increment('hints_used');$piece=collect($v['manifest']['pieces'])->firstWhere('id',$remaining[0]);return ['piece_id'=>$piece['id'],'target_anchor'=>$piece['snap_anchor_px'],'wallet'=>$this->wallet->balance($uid)];}
        Json::fail('unsupported_assistance');
    }
    public function reserve(int $uid,string $attempt,string $resource,int $quantity): array {
        $a=$this->owned($uid,$attempt);if(!$a->offline||$a->state!=='playing'||now()->gte($a->ticket_expires_at))Json::fail('offline_ticket_invalid',409);
        if(!in_array($resource,['hints','shuffle_uses','full_image_uses'],true)||$quantity<1||$quantity>10)Json::fail('invalid_allocation');
        $id=(string)Str::uuid();$this->wallet->change($uid,'reserve:'.$id,[$resource=>-$quantity]);DB::table('offline_allocations')->insert(['id'=>$id,'user_id'=>$uid,'attempt_id'=>$attempt,'resource'=>$resource,'quantity'=>$quantity,'expires_at'=>$a->ticket_expires_at,'created_at'=>now(),'updated_at'=>now()]);return ['allocation_id'=>$id,'resource'=>$resource,'quantity'=>$quantity,'expires_at'=>$a->ticket_expires_at];
    }
    public function sync(int $uid,string $id,array $journal,int $elapsed,array $uses): array {
        $a=$this->owned($uid,$id);if(!$a->offline)Json::fail('not_offline_attempt');if($a->state==='completed')return $this->view($uid,$id);
        if($a->state!=='playing'||now()->gte($a->ticket_expires_at))Json::fail('offline_ticket_expired',409,['preserve_local_progress'=>true]);
        $wall=(int)max(0,CarbonImmutable::parse($a->created_at)->diffInMilliseconds(now()));if($elapsed<0||$elapsed>$wall+2000)Json::fail('invalid_offline_elapsed');
        $counts=['hints'=>0,'shuffle_uses'=>0,'full_image_uses'=>0];foreach($uses as$use){$allocation=DB::table('offline_allocations')->where('id',$use['allocation_id'])->where('user_id',$uid)->where('attempt_id',$id)->lockForUpdate()->first();if(!$allocation||$use['used']<0||$use['used']>$allocation->quantity)Json::fail('unauthorized_offline_booster');$counts[$allocation->resource]+=$use['used'];DB::table('offline_allocations')->where('id',$allocation->id)->update(['used'=>$use['used'],'updated_at'=>now()]);}
        if(count(array_unique(array_column($uses,'allocation_id')))!==count($uses))Json::fail('duplicate_allocation');
        $this->place($a,$journal);$v=Json::read($a->snapshot);if(count(Json::read(DB::table('attempts')->where('id',$id)->value('placed')))!==$v['piece_count'])Json::fail('incomplete_offline_journal');
        DB::table('attempts')->where('id',$id)->update(['hints_used'=>$counts['hints'],'shuffles_used'=>$counts['shuffle_uses'],'full_images_used'=>$counts['full_image_uses']]);
        foreach(DB::table('offline_allocations')->where('attempt_id',$id)->get()as$allocation){$remaining=$allocation->quantity-$allocation->used;if($remaining){$m=Json::read(DB::table('ledger')->where('user_id',$uid)->where('reference','reserve:'.$allocation->id)->value('metadata'));$this->wallet->change($uid,'reserve-refund:'.$allocation->id,[$allocation->resource=>$remaining],[],(bool)$m['spent_transferable'],$m['spent_origins']);}}
        $this->finish($uid,$id,$elapsed,false);return $this->view($uid,$id)+['verification'=>'journal_validated_no_weekly_rank','client_journal_not_human_play_attestation'=>true];
    }
    private function awardBadges(int $uid): void {
        $p=DB::table('progress')->where('user_id',$uid)->get();$n=$p->count();$stars=$p->sum('best_stars');$threes=$p->where('best_stars',3)->count();$all=collect(config('puzzlequest.rules.collections.launch_level_image_ids'))->diff($p->pluck('level_id'))->isEmpty();
        foreach(['first_steps'=>$n>0,'green_valley_explorer'=>$all,'perfect_solver'=>$threes>0,'star_collector'=>$stars>=10,'puzzle_master'=>$threes>=3]as$id=>$eligible)if($eligible)DB::table('claims')->insertOrIgnore(['user_id'=>$uid,'type'=>'achievement','reference'=>$id,'created_at'=>now()]);
    }
    public function leaderboard(int $uid): array {
        $start=now()->startOfWeek(\Carbon\CarbonInterface::MONDAY);$users=DB::table('users')->where('is_guest',false)->whereNotNull('email_verified_at')->where('visibility','public')->where('status','active')->get()->keyBy('id');$groups=DB::table('attempts')->where('state','completed')->where('rank_verified',true)->where('completed_at','>=',$start)->whereIn('user_id',$users->keys())->get()->groupBy('user_id');$rows=[];
        foreach($groups as$playerId=>$attempts){$best=$attempts->groupBy('level_id')->map(fn($a)=>$a->sort(function($a,$b){return ($b->score<=>$a->score)?:($b->rating<=>$a->rating)?:($a->elapsed_ms<=>$b->elapsed_ms)?:strcmp($a->completed_at,$b->completed_at);})->first());$u=$users[$playerId];$rows[]=['player_id'=>$playerId,'name'=>$u->name,'avatar'=>$u->avatar,'score'=>$best->sum('score'),'stars'=>$best->sum('rating'),'elapsed_ms'=>$best->sum('elapsed_ms'),'reached_at'=>$best->max('completed_at')];}
        usort($rows,fn($a,$b)=>($b['score']<=>$a['score'])?:($b['stars']<=>$a['stars'])?:($a['elapsed_ms']<=>$b['elapsed_ms'])?:strcmp($a['reached_at'],$b['reached_at'])?:($a['player_id']<=>$b['player_id']));foreach($rows as$i=>&$row)$row['rank']=$i+1;unset($row);
        return ['period'=>'weekly_global','starts_at'=>$start->toIso8601String(),'ends_at'=>$start->copy()->addWeek()->toIso8601String(),'rows'=>array_slice($rows,0,100),'me'=>collect($rows)->firstWhere('player_id',$uid)];
    }
}
