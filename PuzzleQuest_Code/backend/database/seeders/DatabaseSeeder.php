<?php
namespace Database\Seeders;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
final class DatabaseSeeder extends Seeder {
    public function run(): void {
        foreach(config('puzzlequest.rules.content.worlds')as$i=>$w)DB::table('worlds')->insertOrIgnore(['id'=>$w['world_id'],'title'=>json_encode(['en'=>$w['name'],'ar'=>['الوادي الأخضر','أرض الثلج','أطلال الصحراء'][$i]]),'position'=>$i+1,'published'=>$i===0,'created_at'=>now(),'updated_at'=>now()]);
        $levels=json_decode(file_get_contents(resource_path('product/launch-content.json')),true);$previous=null;
        foreach($levels as$l){DB::table('levels')->insertOrIgnore(['id'=>$l['level_id'],'world_id'=>$l['world_id'],'display_code'=>$l['display_code'],'position'=>$l['position'],'title'=>json_encode($l['title']),'previous_level_id'=>$previous,'published'=>true,'created_at'=>now(),'updated_at'=>now()]);$previous=$l['level_id'];
            $revision=DB::table('content_revisions')->where('level_id',$l['level_id'])->where('revision',$l['revision'])->first();if(!$revision){$id=(string)Str::uuid();DB::table('content_revisions')->insert(['id'=>$id,'level_id'=>$l['level_id'],'revision'=>$l['revision'],'state'=>'published','payload'=>json_encode($l['payload']),'validation'=>json_encode(['owner_conditional_launch_art'=>true,'device_qa'=>false]),'published_at'=>now(),'created_at'=>now(),'updated_at'=>now()]);DB::table('levels')->where('id',$l['level_id'])->update(['active_revision_id'=>$id]);}
        }
        foreach(['privacy','terms','delete-account','help']as$slug)foreach(['ar','en']as$locale)DB::table('legal_documents')->insertOrIgnore(['slug'=>$slug,'locale'=>$locale,'version'=>'draft','body'=>'','approved'=>false,'created_at'=>now(),'updated_at'=>now()]);
    }
}
