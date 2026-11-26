<?php
namespace App\Http\Controllers;
use App\Services\{Game,Rewards,Identity,Ads};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Support\Json;
final class GameController extends Controller {
    public function __construct(private Game $game,private Rewards $rewards,private Identity $identity,private Ads $ads){}
    private function uid(Request $r): int {$u=$r->attributes->get('player');$this->identity->eligible($u);return $u->id;}
    public function catalog(Request $r){return response()->json($this->game->catalog($r->attributes->get('player')->id));}
    public function start(Request $r){$d=$r->validate(['level_id'=>'required|string|max:100','offline'=>'sometimes|boolean']);return response()->json($this->game->start($r->attributes->get('player'),$d['level_id'],$d['offline']??false),201);}
    public function view(Request $r,string $id){return response()->json($this->game->view($this->uid($r),$id));}
    public function clock(Request $r,string $id){$d=$r->validate(['action'=>'required|in:pause,resume,ad-start']);return response()->json($this->game->clock($this->uid($r),$id,$d['action']));}
    private function events(Request $r,string $key='events'): array{return $r->validate([$key=>'required|array|min:1|max:100',$key.'.*.event_id'=>'required|uuid',$key.'.*.piece_id'=>'required|string|max:32',$key.'.*.anchor'=>'required|array|size:2',$key.'.*.anchor.*'=>'required|numeric|between:-1000,2000'])[$key];}
    public function eventsBatch(Request $r,string $id){return response()->json($this->game->eventBatch($this->uid($r),$id,$this->events($r)));}
    public function assist(Request $r,string $id){$d=$r->validate(['type'=>'required|in:hint,shuffle','confirm_purchase'=>'sometimes|boolean']);return response()->json($this->game->assist($this->uid($r),$id,$d['type'],$d['confirm_purchase']??false,$r->attributes->get('operation_key')));}
    public function reserve(Request $r,string $id){$d=$r->validate(['resource'=>'required|in:hints,shuffle_uses,full_image_uses','quantity'=>'required|integer|between:1,10']);return response()->json($this->game->reserve($this->uid($r),$id,$d['resource'],$d['quantity']));}
    public function sync(Request $r,string $id){$events=$this->events($r,'journal');$d=$r->validate(['elapsed_ms'=>'required|integer|min:0','allocations'=>'present|array|max:30','allocations.*.allocation_id'=>'required|uuid','allocations.*.used'=>'required|integer|min:0']);return response()->json($this->game->sync($this->uid($r),$id,$events,$d['elapsed_ms'],$d['allocations']));}
    public function shop(){return response()->json(['offers'=>config('puzzlequest.rules.store.offers')]);}
    public function purchase(Request $r){$d=$r->validate(['offer_id'=>'required|string|max:50']);return response()->json($this->rewards->shop($this->uid($r),$d['offer_id'],$r->attributes->get('operation_key')));}
    public function daily(Request $r){return response()->json($this->rewards->daily($this->uid($r)));}
    public function dailyClaim(Request $r){return response()->json($this->rewards->daily($this->uid($r),true));}
    public function missions(Request $r){return response()->json(['missions'=>$this->rewards->missions($this->uid($r)),'events'=>[]]);}
    public function claimMission(Request $r,string $id){return response()->json($this->rewards->mission($this->uid($r),$id));}
    public function chest(Request $r){return response()->json($this->rewards->chest($this->uid($r)));}
    public function collections(Request $r){$uid=$this->uid($r);return response()->json(['pictures'=>DB::table('progress')->where('user_id',$uid)->get(),'achievements'=>DB::table('claims')->where('user_id',$uid)->where('type','achievement')->pluck('reference'),'definitions'=>config('puzzlequest.rules.achievements.entries'),'published_collection_content'=>app(\App\Services\StudioDocuments::class)->publicCatalog('collection')['items'],'published_achievement_art'=>app(\App\Services\StudioDocuments::class)->publicCatalog('achievement')['items']]);}
    public function buildings(Request $r){$uid=$this->uid($r);$rows=[];foreach(config('puzzlequest.rules.village.buildings')as$id=>$rules)$rows[]=['id'=>$id,'stage'=>(int)(DB::table('player_buildings')->where('user_id',$uid)->where('building_id',$id)->value('stage')??0),'transitions'=>$rules['transitions']];return response()->json(['buildings'=>$rows,'published_village_scenes'=>app(\App\Services\StudioDocuments::class)->publicCatalog('village_scene')['items'],'published_village_items'=>app(\App\Services\StudioDocuments::class)->publicCatalog('village_item')['items'],'studio_media_assets'=>app(\App\Services\StudioDocuments::class)->publicCatalog()['assets']]);}
    public function upgrade(Request $r,string $id){$d=$r->validate(['expected_stage'=>'required|integer|between:0,4']);return response()->json($this->rewards->upgrade($this->uid($r),$id,$d['expected_stage']));}
    public function leaderboard(Request $r){return response()->json($this->game->leaderboard($this->uid($r)));}
    public function requestAd(Request $r){$d=$r->validate(['attempt_id'=>'required|uuid','type'=>'required|in:hint,full_image']);return response()->json($this->ads->request($this->uid($r),$d['attempt_id'],$d['type']),201);}
    public function adStatus(Request $r,string $id){$v=DB::table('reward_requests')->where('id',$id)->where('user_id',$this->uid($r))->first(['id','attempt_id','type','state','expires_at']);abort_unless($v,404);return response()->json(['request'=>$v,'entitlements'=>DB::table('preview_entitlements')->where('attempt_id',$v->attempt_id)->where('user_id',$this->uid($r))->get()]);}
    public function ssv(Request $r){return response()->json($this->ads->verifyCallback($r->server('QUERY_STRING','')));}
    public function activatePreview(Request $r,string $id){$d=$r->validate(['entitlement_id'=>'nullable|uuid']);return response()->json($this->ads->activate($this->uid($r),$id,$d['entitlement_id']??null,$r->attributes->get('operation_key')));}
    public function previewTick(Request $r,string $id){$d=$r->validate(['visible_elapsed_ms'=>'required|integer|min:0','action'=>'required|in:tick,pause,close']);return response()->json($this->ads->previewTick($this->uid($r),$id,$d['visible_elapsed_ms'],$d['action']));}
    public function interstitial(Request $r){$d=$r->validate(['attempt_id'=>'required|uuid']);return response()->json($this->ads->interstitial($this->uid($r),$d['attempt_id']));}
}
