<?php
namespace Tests\Feature;

use App\Services\StudioDocuments;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\{DB,Hash};
use Illuminate\Support\Str;
use Tests\TestCase;

final class StudioRemoteManagementTest extends TestCase {
    use RefreshDatabase;
    protected function setUp(): void {parent::setUp();$this->seed(DatabaseSeeder::class);}
    private function admin(string $role='owner'): int {return DB::table('admins')->insertGetId(['name'=>'Studio Tester','email'=>Str::uuid().'@example.com','password'=>Hash::make('Secure-Testing-Password-123'),'role'=>$role,'created_at'=>now(),'updated_at'=>now()]);}
    private function bearer(?int $id=null): array {$id??=$this->admin();$plain=bin2hex(random_bytes(32));DB::table('studio_access_tokens')->insert(['id'=>(string)Str::uuid(),'admin_id'=>$id,'name'=>'Test Desktop','token_hash'=>hash('sha256',$plain),'expires_at'=>now()->addDays(7),'created_at'=>now(),'updated_at'=>now()]);return ['Authorization'=>'Bearer '.$plain];}
    public function test_studio_endpoints_deny_unpaired_and_expired_clients(): void {
        $this->getJson('/api/studio/v1/worlds')->assertUnauthorized();
        $admin=$this->admin();$headers=$this->bearer($admin);DB::table('studio_access_tokens')->update(['expires_at'=>now()->subDay()]);
        $this->getJson('/api/studio/v1/schema',$headers)->assertUnauthorized();
    }
    public function test_only_owner_with_recent_reauth_can_create_pairing_token(): void {
        $id=$this->admin('content');$this->withSession(['admin_id'=>$id,'admin_reauth_at'=>time()])->post('/admin/studio/tokens',['name'=>'Windows'])->assertForbidden();
        $owner=$this->admin();$this->withSession(['admin_id'=>$owner,'admin_reauth_at'=>time()-700])->post('/admin/studio/tokens',['name'=>'Windows'])->assertForbidden();
        $result=$this->withSession(['admin_id'=>$owner,'admin_reauth_at'=>time()])->post('/admin/studio/tokens',['name'=>'Windows Desktop']);$result->assertOk()->assertSee('Windows Desktop');
        $this->assertSame(1,DB::table('studio_access_tokens')->where('admin_id',$owner)->count());
        $this->assertSame(64,strlen(DB::table('studio_access_tokens')->where('admin_id',$owner)->value('token_hash')));
    }
    public function test_draft_world_and_level_are_not_automatically_published(): void {
        $auth=$this->bearer();
        $this->postJson('/api/studio/v1/worlds',['id'=>'studio_world','title'=>['ar'=>'عالم','en'=>'World'],'position'=>9],$auth)->assertCreated();
        $this->postJson('/api/studio/v1/levels',['id'=>'studio_level_001','world_id'=>'studio_world','display_code'=>'9-1','position'=>1,'title'=>['ar'=>'مرحلة','en'=>'Level']],$auth)->assertCreated();
        $this->assertDatabaseHas('worlds',['id'=>'studio_world','published'=>false]);
        $this->assertDatabaseHas('levels',['id'=>'studio_level_001','published'=>false]);
        $this->patchJson('/api/studio/v1/worlds/studio_world',['title'=>['ar'=>'عالم','en'=>'World'],'position'=>9,'published'=>true],$auth)->assertUnprocessable();
    }
    public function test_village_document_requires_known_image_ids_and_published_snapshot_is_immutable(): void {
        $auth=$this->bearer();
        $a=$this->postJson('/api/studio/v1/documents',['kind'=>'village_scene','slug'=>'test-village','world_id'=>'green_valley','title'=>['ar'=>'قرية','en'=>'Village'],'position'=>1,'payload'=>['background_asset_id'=>null,'objects'=>[]]],$auth)->assertCreated()->json();
        $id=$a['id'];
        $this->postJson('/api/studio/v1/documents/'.$id.'/publish',['draft_revision'=>1,'content_qa_approved'=>true],$auth)->assertUnprocessable();
        $media=(string)Str::uuid();DB::table('studio_media')->insert(['id'=>$media,'relative_path'=>'studio-media/'.$media.'.png','mime'=>'image/png','width'=>960,'height'=>960,'bytes'=>5000,'sha256'=>str_repeat('b',64),'created_by'=>1,'created_at'=>now()]);
        $payload=['background_asset_id'=>$media,'objects'=>[]];
        $this->patchJson('/api/studio/v1/documents/'.$id,['draft_revision'=>1,'world_id'=>'green_valley','title'=>['ar'=>'قرية','en'=>'Village'],'position'=>1,'payload'=>$payload],$auth)->assertOk()->assertJsonPath('draft_revision',2);
        $this->postJson('/api/studio/v1/documents/'.$id.'/publish',['draft_revision'=>2,'content_qa_approved'=>true],$auth)->assertOk()->assertJsonPath('live_revision',1);
        $this->patchJson('/api/studio/v1/documents/'.$id,['draft_revision'=>2,'world_id'=>'green_valley','title'=>['ar'=>'نسخة جديدة','en'=>'New draft'],'position'=>1,'payload'=>$payload],$auth)->assertOk()->assertJsonPath('draft_revision',3);
        $this->getJson('/api/v1/studio-content')->assertOk()->assertJsonPath('items.0.title.en','Village');
        $this->postJson('/api/studio/v1/documents/'.$id.'/publish',['draft_revision'=>2,'content_qa_approved'=>true],$auth)->assertStatus(409);
        $this->postJson('/api/studio/v1/documents/'.$id.'/restore/1',['draft_revision'=>3],$auth)->assertOk()->assertJsonPath('draft_revision',4);
    }
    public function test_public_events_are_only_visible_in_their_active_window(): void {
        $auth=$this->bearer();$d=['kind'=>'event','slug'=>'seasonal-future','world_id'=>'green_valley','title'=>['ar'=>'حدث','en'=>'Event'],'position'=>1,'payload'=>['starts_at'=>now()->addDay()->toIso8601String(),'ends_at'=>now()->addDays(4)->toIso8601String()]];
        $id=$this->postJson('/api/studio/v1/documents',$d,$auth)->assertCreated()->json('id');
        $this->postJson('/api/studio/v1/documents/'.$id.'/publish',['draft_revision'=>1,'content_qa_approved'=>true],$auth)->assertOk();
        $this->getJson('/api/v1/studio-content?kind=event')->assertOk()->assertJsonCount(0,'items');
        $this->travel(2)->days();$this->getJson('/api/v1/studio-content?kind=event')->assertOk()->assertJsonCount(1,'items');
    }
}
