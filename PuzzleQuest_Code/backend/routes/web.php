<?php

use Illuminate\Support\Facades\{Route,DB};
use Illuminate\Http\Request;
use App\Http\Controllers\AdminController;
Route::get('/',fn()=>redirect('/admin'));
Route::get('/health',function(){try{DB::select('SELECT 1');$ready=is_file(storage_path('installed.lock'));return response()->json(['application'=>$ready?'ready':'not_installed','database'=>'reachable','version'=>app(\App\Services\Updates::class)->version()],$ready?200:503);}catch(\Throwable $e){return response()->json(['application'=>'unavailable'],503);}});
Route::get('/admin/login',[AdminController::class,'login']);Route::post('/admin/login',[AdminController::class,'authenticate'])->middleware('throttle:admin-login');
Route::middleware('administrator')->group(function(){Route::get('/admin',[AdminController::class,'page']);Route::get('/admin/module/{module}',[AdminController::class,'page'])->whereNumber('module');Route::post('/admin/module/{module}',[AdminController::class,'action'])->whereNumber('module');Route::post('/admin/logout',[AdminController::class,'logout']);Route::post('/admin/reauth',[AdminController::class,'reauth'])->middleware('throttle:admin-login');Route::get('/admin/backups/{name}',[AdminController::class,'downloadBackup']);Route::get('/admin/support/{id}/image',[AdminController::class,'supportImage']);});
foreach(['privacy','terms','delete-account','help']as$slug)Route::get('/'.$slug,function(Request $r)use($slug){$locale=$r->query('lang','ar');abort_unless(in_array($locale,['ar','en'],true),404);$doc=DB::table('legal_documents')->where('slug',$slug)->where('locale',$locale)->where('approved',true)->whereNotNull('published_at')->first();return response()->view('legal',['document'=>$doc,'slug'=>$slug,'locale'=>$locale],$doc?200:503);});

// Owner-only desktop pairing. Session CSRF + fresh admin reauthentication required.
Route::middleware('administrator')->group(function(){
    Route::get('/admin/studio',[\App\Http\Controllers\StudioPairingController::class,'index']);
    Route::post('/admin/studio/tokens',[\App\Http\Controllers\StudioPairingController::class,'create'])->middleware('throttle:admin-login');
    Route::post('/admin/studio/tokens/{id}/revoke',[\App\Http\Controllers\StudioPairingController::class,'revoke'])->middleware('throttle:admin-login');
});
