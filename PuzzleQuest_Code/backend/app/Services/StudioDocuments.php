<?php
namespace App\Services;

use App\Support\Json;
use Illuminate\Support\Facades\{DB,Validator};
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/** Draft-first, immutable published snapshots; visual content does not mint player rewards. */
final class StudioDocuments {
    public const KINDS = ['collection','level_group','world_art','village_scene','village_item','event','mission','achievement','banner','story'];
    public function validateKind(string $kind): void {abort_unless(in_array($kind,self::KINDS,true),404);}
    private function existsAsset(?string $id): void {if($id!==null && !DB::table('studio_media')->where('id',$id)->exists())throw ValidationException::withMessages(['payload'=>'Unknown image asset ID: '.$id]);}
    private function existsLevels(array $ids): void {foreach($ids as $id)if(!DB::table('levels')->where('id',$id)->exists())throw ValidationException::withMessages(['payload'=>'Unknown level ID: '.$id]);}
    public function validateData(string $kind,array $payload): array {
        $this->validateKind($kind);
        if(strlen(Json::encode($payload))>131072)throw ValidationException::withMessages(['payload'=>'Document is too large']);
        // Strictly validate the keys that affect placement, asset selection or schedule.
        Validator::make(['payload'=>$payload],[
            'payload'=>'present|array',
            'payload.background_asset_id'=>'nullable|uuid',
            'payload.cover_asset_id'=>'nullable|uuid',
            'payload.image_asset_id'=>'nullable|uuid',
            'payload.banner_asset_id'=>'nullable|uuid',
            'payload.level_ids'=>'sometimes|array|max:200',
            'payload.level_ids.*'=>'string|max:100',
            'payload.objects'=>'sometimes|array|max:150',
            'payload.objects.*.asset_id'=>'required_with:payload.objects|uuid',
            'payload.objects.*.x'=>'required_with:payload.objects|numeric|between:0,1',
            'payload.objects.*.y'=>'required_with:payload.objects|numeric|between:0,1',
            'payload.objects.*.scale'=>'required_with:payload.objects|numeric|between:0.1,4',
            'payload.objects.*.z'=>'required_with:payload.objects|integer|between:-100,100',
            'payload.objects.*.building_id'=>'nullable|string|max:64',
            'payload.objects.*.stage'=>'nullable|integer|between:0,4',
            'payload.starts_at'=>'nullable|date',
            'payload.ends_at'=>'nullable|date|after:payload.starts_at',
            'payload.description.ar'=>'nullable|string|max:2000',
            'payload.description.en'=>'nullable|string|max:2000',
        ])->validate();
        if($kind==='village_scene'){
            if(!array_key_exists('background_asset_id',$payload))throw ValidationException::withMessages(['payload'=>'Village scene requires background_asset_id (null allowed)']);
            if(!is_array($payload['objects']??null))throw ValidationException::withMessages(['payload'=>'Village scene requires objects array']);
        }
        if($kind==='village_item' && empty($payload['image_asset_id']))throw ValidationException::withMessages(['payload'=>'Village item requires image_asset_id']);
        if($kind==='event' && (empty($payload['starts_at'])||empty($payload['ends_at'])))throw ValidationException::withMessages(['payload'=>'Event requires starts_at and ends_at']);
        foreach(['background_asset_id','cover_asset_id','image_asset_id','banner_asset_id']as $key)$this->existsAsset($payload[$key]??null);
        $objIds=[];foreach(($payload['objects']??[])as $object){$this->existsAsset($object['asset_id']??null);if(!empty($object['id'])){if(!preg_match('/^[a-z0-9_-]{1,70}$/D',$object['id'])||in_array($object['id'],$objIds,true))throw ValidationException::withMessages(['payload'=>'Duplicate/invalid village object id']);$objIds[]=$object['id'];}}
        $this->existsLevels($payload['level_ids']??[]);
        return $payload;
    }
    public function index(string $kind,?string $worldId=null): array {
        $this->validateKind($kind);$query=DB::table('studio_documents')->where('kind',$kind);
        if($worldId)$query->where('world_id',$worldId);
        return $query->orderBy('position')->limit(500)->get()->map(fn($x)=>$this->serialize($x))->all();
    }
    public function serialize(object $r,bool $publishedOnly=false): array {
        $live=$r->published_payload?Json::read($r->published_payload):null;
        $draft=Json::read($r->draft_payload);
        $pending=$live!==null && ($live['payload']!==$draft || $live['title']!==Json::read($r->title) || $live['position']!==(int)$r->position || $live['world_id']!==$r->world_id);
        return ['id'=>$r->id,'kind'=>$r->kind,'slug'=>$r->slug,'world_id'=>$r->world_id,'title'=>Json::read($r->title),'position'=>(int)$r->position,'state'=>$r->state,'draft_revision'=>(int)$r->draft_revision,'live_revision'=>(int)$r->live_revision,'has_pending_changes'=>$pending,'draft_payload'=>$publishedOnly?null:$draft,'published_payload'=>$live,'published_at'=>$r->published_at];
    }
    public function create(array $data,int $actor): array {
        $this->validateKind($data['kind']);$this->validateData($data['kind'],$data['payload']);
        if(!empty($data['world_id'])&&!DB::table('worlds')->where('id',$data['world_id'])->exists())throw ValidationException::withMessages(['world_id'=>'Unknown world']);
        $id=(string)Str::uuid();DB::table('studio_documents')->insert(['id'=>$id,'kind'=>$data['kind'],'slug'=>$data['slug'],'world_id'=>$data['world_id']??null,'title'=>Json::encode($data['title']),'position'=>$data['position'],'draft_payload'=>Json::encode($data['payload']),'created_by'=>$actor,'created_at'=>now(),'updated_at'=>now()]);
        return $this->serialize(DB::table('studio_documents')->where('id',$id)->first());
    }
    public function edit(string $id,array $data,int $expected): array {
        return DB::transaction(function()use($id,$data,$expected){$row=DB::table('studio_documents')->where('id',$id)->lockForUpdate()->first();abort_unless($row,404);
            if((int)$row->draft_revision!==$expected)abort(409,'Draft changed; refresh before editing');
            if($row->state==='retired')abort(409,'Retired content cannot be modified');
            $this->validateData($row->kind,$data['payload']);
            if(!empty($data['world_id'])&&!DB::table('worlds')->where('id',$data['world_id'])->exists())throw ValidationException::withMessages(['world_id'=>'Unknown world']);
            DB::table('studio_documents')->where('id',$id)->update(['title'=>Json::encode($data['title']),'position'=>$data['position'],'world_id'=>$data['world_id']??null,'draft_payload'=>Json::encode($data['payload']),'draft_revision'=>$expected+1,'updated_at'=>now()]);
            return $this->serialize(DB::table('studio_documents')->where('id',$id)->first());
        });
    }
    public function publish(string $id,int $actor,int $expected): array {
        return DB::transaction(function()use($id,$actor,$expected){$r=DB::table('studio_documents')->where('id',$id)->lockForUpdate()->first();abort_unless($r,404);
            if($r->state==='retired'||(int)$r->draft_revision!==$expected)abort(409,'Document changed or retired');
            $snapshot=Json::read($r->draft_payload);$this->validateData($r->kind,$snapshot);
            if($r->kind==='collection'&&empty($snapshot['level_ids']))throw ValidationException::withMessages(['payload'=>'Collection requires at least one existing level']);
            if($r->kind==='banner'&&empty($snapshot['image_asset_id']))throw ValidationException::withMessages(['payload'=>'Banner requires an uploaded image_asset_id']);
            if($r->kind==='world_art'&&empty($snapshot['background_asset_id'])&&empty($snapshot['cover_asset_id']))throw ValidationException::withMessages(['payload'=>'World art requires a background_asset_id or cover_asset_id']);
            if($r->kind==='village_scene'&&empty($snapshot['background_asset_id'])&&empty($snapshot['objects']))throw ValidationException::withMessages(['payload'=>'Village scene needs a background or placed objects']);
            $revision=(int)$r->live_revision+1;$record=['id'=>$r->id,'kind'=>$r->kind,'slug'=>$r->slug,'world_id'=>$r->world_id,'title'=>Json::read($r->title),'position'=>(int)$r->position,'payload'=>$snapshot,'revision'=>$revision];
            DB::table('studio_document_history')->insert(['id'=>(string)Str::uuid(),'document_id'=>$id,'revision'=>$revision,'snapshot'=>Json::encode($record),'admin_id'=>$actor,'published_at'=>now()]);
            DB::table('studio_documents')->where('id',$id)->update(['state'=>'published','published_payload'=>Json::encode($record),'live_revision'=>$revision,'published_at'=>now(),'updated_at'=>now()]);
            return $this->serialize(DB::table('studio_documents')->where('id',$id)->first());
        });
    }
    public function restoreToDraft(string $id,int $revision,int $expected): array {
        return DB::transaction(function()use($id,$revision,$expected){
            $row=DB::table('studio_documents')->where('id',$id)->lockForUpdate()->first();abort_unless($row,404);
            if($row->state==='retired'||(int)$row->draft_revision!==$expected)abort(409,'Document changed or retired');
            $prior=DB::table('studio_document_history')->where('document_id',$id)->where('revision',$revision)->first();abort_unless($prior,404);
            $snapshot=Json::read($prior->snapshot);$this->validateData($row->kind,$snapshot['payload']);
            DB::table('studio_documents')->where('id',$id)->update(['title'=>Json::encode($snapshot['title']),'world_id'=>$snapshot['world_id'],'position'=>$snapshot['position'],'draft_payload'=>Json::encode($snapshot['payload']),'draft_revision'=>$expected+1,'updated_at'=>now()]);
            return $this->serialize(DB::table('studio_documents')->where('id',$id)->first());
        });
    }
    public function retire(string $id): array {$r=DB::table('studio_documents')->where('id',$id)->first();abort_unless($r,404);if($r->state!=='published')abort(409,'Only published content may be retired');DB::table('studio_documents')->where('id',$id)->update(['state'=>'retired','updated_at'=>now()]);return $this->serialize(DB::table('studio_documents')->where('id',$id)->first());}
    public function publicCatalog(?string $kind=null): array {
        $q=DB::table('studio_documents')->where('state','published')->whereNotNull('published_payload');
        if($kind){$this->validateKind($kind);$q->where('kind',$kind);}
        $publishedWorldIds=DB::table('worlds')->where('published',true)->pluck('id')->all();
        $items=$q->orderBy('kind')->orderBy('position')->limit(1000)->get()->filter(function($x)use($publishedWorldIds){
            $snapshot=Json::read($x->published_payload);
            if(($snapshot['world_id']??null)!==null&&!in_array($snapshot['world_id'],$publishedWorldIds,true))return false;
            if($x->kind==='event'){
                $payload=$snapshot['payload']??[];
                if(empty($payload['starts_at'])||empty($payload['ends_at']))return false;
                return now()->betweenIncluded(\Carbon\CarbonImmutable::parse($payload['starts_at']),\Carbon\CarbonImmutable::parse($payload['ends_at']));
            }
            return true;
        })->map(fn($x)=>Json::read($x->published_payload))->values()->all();
        $assetIds=[];
        foreach($items as $item){$payload=$item['payload']??[];
            foreach(['background_asset_id','cover_asset_id','image_asset_id','banner_asset_id']as $key)if(!empty($payload[$key]))$assetIds[$payload[$key]]=true;
            foreach(($payload['objects']??[])as $object)if(!empty($object['asset_id']))$assetIds[$object['asset_id']]=true;
        }
        $assets=[];
        if($assetIds)foreach(DB::table('studio_media')->whereIn('id',array_keys($assetIds))->get()as $asset)
            $assets[$asset->id]=['url'=>url('studio-media/'.basename($asset->relative_path)),'sha256'=>$asset->sha256,'width'=>(int)$asset->width,'height'=>(int)$asset->height,'mime'=>$asset->mime];
        return ['schema_version'=>1,'generated_at'=>now()->toIso8601String(),'items'=>$items,'assets'=>$assets];
    }
}
