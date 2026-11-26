<?php
namespace App\Http\Middleware;
use Closure;
use Illuminate\Support\Facades\DB;
final class Administrator {
    public function handle($r, Closure $next, string $roles='owner,content,support,analyst') {
        $admin=DB::table('admins')->where('id',$r->session()->get('admin_id'))->where('active',true)->first();
        if(!$admin) return redirect('/admin/login');
        abort_unless(in_array($admin->role,explode(',',$roles),true),403);
        $r->attributes->set('admin',$admin); return $next($r);
    }
}
