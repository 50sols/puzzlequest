<?php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\{AuthController as Auth,GameController as Game,AccountController as Account};
Route::prefix('v1')->middleware('throttle:api')->group(function(){
    Route::get('status',fn()=>response()->json(['service'=>'PuzzleQuest','version'=>config('puzzlequest.version'),'time'=>now()->toIso8601String()]));
    Route::prefix('auth')->middleware('throttle:identity')->group(function(){
        Route::post('guest',[Auth::class,'guest']);Route::post('register',[Auth::class,'register']);Route::post('login',[Auth::class,'login']);
        Route::post('otp/request',[Auth::class,'otp']);Route::post('otp/verify',[Auth::class,'verify']);Route::post('password/reset',[Auth::class,'reset']);
        Route::post('google/challenge',[Auth::class,'challenge']);Route::post('google',[Auth::class,'google']);
        Route::post('account/recovery/request',[Account::class,'recoveryRequest']);Route::post('account/recovery/confirm',[Account::class,'recoveryConfirm']);
    });
    Route::get('ads/ssv',[Game::class,'ssv'])->middleware('throttle:ssv');
    Route::post('support/recovery/request',[\App\Http\Controllers\SupportRecoveryController::class,'request'])->middleware('throttle:identity');
    Route::post('support/recovery/verify',[\App\Http\Controllers\SupportRecoveryController::class,'verify'])->middleware('throttle:identity');
    Route::get('support/recovered/{id}',[\App\Http\Controllers\SupportRecoveryController::class,'view']);
    Route::post('support/recovered/{id}/reply',[\App\Http\Controllers\SupportRecoveryController::class,'reply'])->middleware('throttle:identity');
    Route::middleware('player')->group(function(){
        Route::get('me',[Auth::class,'me']);Route::post('auth/logout',[Auth::class,'logout']);
        Route::post('account/reauth',[Auth::class,'reauth'])->middleware('throttle:identity');Route::post('account/reauth/request',[Auth::class,'reauthRequest'])->middleware('throttle:identity');Route::post('account/reauth/verify',[Auth::class,'reauthVerify'])->middleware('throttle:identity');
        Route::get('catalog',[Game::class,'catalog']);Route::get('attempts/{id}',[Game::class,'view']);Route::get('shop',[Game::class,'shop']);
        Route::get('rewards/daily',[Game::class,'daily']);Route::get('missions',[Game::class,'missions']);Route::get('collections',[Game::class,'collections']);Route::get('village',[Game::class,'buildings']);Route::get('leaderboard/weekly',[Game::class,'leaderboard']);Route::get('ads/requests/{id}',[Game::class,'adStatus']);
        Route::get('account/devices',[Account::class,'devices']);Route::get('account/exports',[Account::class,'exports']);Route::get('account/exports/{id}/download',[Account::class,'downloadExport']);
        Route::get('inbox',[Account::class,'inbox']);Route::get('support/tickets',[Account::class,'tickets']);Route::get('support/tickets/{id}',[Account::class,'ticket']);Route::get('support/tickets/{id}/image',[Account::class,'ticketImage']);
        Route::middleware('operation')->group(function(){
            Route::post('account/register',[Auth::class,'register']);Route::post('account/merge',[Auth::class,'merge']);
            Route::post('account/google/link',[Auth::class,'linkGoogle']);
            Route::post('attempts',[Game::class,'start']);Route::post('attempts/{id}/clock',[Game::class,'clock']);Route::post('attempts/{id}/events',[Game::class,'eventsBatch']);
            Route::post('attempts/{id}/assistance',[Game::class,'assist']);Route::post('attempts/{id}/offline/reserve',[Game::class,'reserve']);Route::post('attempts/{id}/offline/sync',[Game::class,'sync']);
            Route::post('shop/purchases',[Game::class,'purchase']);Route::post('rewards/daily/claim',[Game::class,'dailyClaim']);Route::post('missions/{id}/claim',[Game::class,'claimMission']);Route::post('rewards/chest/claim',[Game::class,'chest']);Route::post('village/{id}/upgrade',[Game::class,'upgrade']);
            Route::post('ads/requests',[Game::class,'requestAd']);Route::post('ads/interstitial/authorize',[Game::class,'interstitial']);Route::post('attempts/{id}/preview/activate',[Game::class,'activatePreview']);Route::post('previews/{id}/lifecycle',[Game::class,'previewTick']);
            Route::patch('account/profile',[Account::class,'profile']);Route::post('account/consent',[Account::class,'consent']);Route::post('account/devices/revoke',[Account::class,'revoke']);Route::post('account/email/request',[Account::class,'emailRequest']);
            Route::post('account/exports',[Account::class,'export']);Route::post('account/deletion',[Account::class,'delete']);
            Route::post('inbox/read',[Account::class,'readInbox']);Route::post('inbox/read-all',[Account::class,'readAll']);Route::post('support/tickets',[Account::class,'createTicket']);Route::post('support/tickets/{id}/reply',[Account::class,'replyTicket']);Route::post('push/devices',[Account::class,'pushDevice']);
        });
        // Verification attempts commit their failure counters independently of mutation idempotency transactions.
        Route::post('account/email/confirm',[Account::class,'emailConfirm'])->middleware('throttle:identity');
    });
});

// Remote Studio API. Session cookies do not authenticate these routes.
Route::get('v1/studio-content',[\App\Http\Controllers\StudioApiController::class,'publicCatalog'])->middleware('throttle:api');
Route::prefix('studio/v1')->middleware(['studio.token','throttle:api'])->controller(\App\Http\Controllers\StudioApiController::class)->group(function(){
    Route::get('schema','schema');
    Route::get('worlds','worlds');Route::post('worlds','createWorld');Route::patch('worlds/{id}','updateWorld');
    Route::get('levels','levels');Route::post('levels','createLevel');Route::patch('levels/{id}','updateLevel');Route::post('levels/{id}/unpublish','unpublishLevel');
    Route::get('revisions','revisions');Route::post('revisions/import','importLevel');Route::post('revisions/{id}/publish','publishLevel');
    Route::get('documents/{kind}','documentList');Route::post('documents','createDocument');Route::patch('documents/{id}','updateDocument');
    Route::post('documents/{id}/publish','publishDocument');Route::post('documents/{id}/retire','retireDocument');Route::post('documents/{id}/restore/{revision}','restoreDocument')->whereNumber('revision');Route::get('documents/{id}/history','history');
    Route::get('media','media');Route::post('media','uploadMedia');
});
