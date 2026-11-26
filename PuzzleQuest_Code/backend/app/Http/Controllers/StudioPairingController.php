<?php
namespace App\Http\Controllers;

use App\Services\Settings;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class StudioPairingController extends Controller {
    private function guard(Request $r): object {
        $admin=$r->attributes->get('admin');abort_unless($admin&&$admin->role==='owner',403);return $admin;
    }
    public function index(Request $r){$admin=$this->guard($r);return view('admin.studio-pairing',['admin'=>$admin,'tokens'=>DB::table('studio_access_tokens')->where('admin_id',$admin->id)->orderByDesc('created_at')->limit(100)->get()]);}
    public function create(Request $r){$admin=$this->guard($r);
        abort_unless(time()-(int)$r->session()->get('admin_reauth_at',0)<=600,403,'Confirm admin password first');
        $data=$r->validate(['name'=>'required|string|min:3|max:100']);
        $plain=bin2hex(random_bytes(32));$id=(string)Str::uuid();
        DB::table('studio_access_tokens')->insert(['id'=>$id,'admin_id'=>$admin->id,'name'=>$data['name'],'token_hash'=>hash('sha256',$plain),'expires_at'=>now()->addDays(7),'created_at'=>now(),'updated_at'=>now()]);
        app(Settings::class)->audit($admin->id,'studio.token.create',$id,['name'=>$data['name'],'expires_in_days'=>7]);
        $tokens=DB::table('studio_access_tokens')->where('admin_id',$admin->id)->orderByDesc('created_at')->limit(100)->get();
        return response()->view('admin.studio-pairing',compact('admin','tokens')+['issuedToken'=>$plain])->header('Cache-Control','no-store');
    }
    public function revoke(Request $r,string $id){$admin=$this->guard($r);abort_unless(time()-(int)$r->session()->get('admin_reauth_at',0)<=600,403);
        $changed=DB::table('studio_access_tokens')->where('id',$id)->where('admin_id',$admin->id)->whereNull('revoked_at')->update(['revoked_at'=>now(),'updated_at'=>now()]);abort_unless($changed,404);
        app(Settings::class)->audit($admin->id,'studio.token.revoke',$id);return redirect('/admin/studio')->with('success','تم إلغاء الاتصال');
    }
}
