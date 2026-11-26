<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Support\Facades\{RateLimiter,DB,Schema};

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('api',fn($r)=>Limit::perMinute(180)->by(hash('sha256',$r->bearerToken()?:$r->ip())));
        RateLimiter::for('identity',fn($r)=>Limit::perMinute(12)->by($r->ip()));
        RateLimiter::for('ssv',fn($r)=>Limit::perMinute(600)->by($r->ip()));
        RateLimiter::for('admin-login',fn($r)=>Limit::perMinute(5)->by($r->ip()));
        if(is_file(storage_path('installed.lock'))){
            try{if(Schema::hasTable('settings')){
                $settings=app(\App\Services\Settings::class);
                foreach(['legal_approved','delete_enabled']as$key){$value=$settings->get($key);if($value!==null)config(['puzzlequest.'.$key=>$value]);}
                foreach(['google_client_id','release_public_key','ad_units']as$key){$value=$settings->get($key);if($value!==null)config(['puzzlequest.'.$key=>$value]);}
                $prices=$settings->get('offer_prices',[]);$offers=config('puzzlequest.rules.store.offers');foreach($offers as&$offer)if(isset($prices[$offer['id']]))$offer['price_coins']=(int)$prices[$offer['id']];unset($offer);config(['puzzlequest.rules.store.offers'=>$offers]);
                if($daily=$settings->get('daily_rewards'))config(['puzzlequest.rules.daily_reward.days'=>$daily]);
                $buildingPrices=$settings->get('building_prices',[]);$buildings=config('puzzlequest.rules.village.buildings');foreach($buildings as$id=>&$building)foreach($building['transitions']as&$transition)if(isset($buildingPrices[$id.':'.$transition['to_stage']]))$transition['price_coins']=(int)$buildingPrices[$id.':'.$transition['to_stage']];unset($building,$transition);config(['puzzlequest.rules.village.buildings'=>$buildings]);
                if($smtp=$settings->get('smtp'))config(['mail.default'=>'smtp','mail.mailers.smtp.host'=>$smtp['host'],'mail.mailers.smtp.port'=>$smtp['port'],'mail.mailers.smtp.username'=>$smtp['username'],'mail.mailers.smtp.password'=>$smtp['password'],'mail.mailers.smtp.scheme'=>$smtp['scheme']??'smtp','mail.from.address'=>$smtp['from'],'mail.from.name'=>'PuzzleQuest']);
            }}catch(\Throwable $e){/* Health/installer expose availability without leaking database credentials. */}
        }
    }

    /**
     * Bootstrap any application services.
     */
    public function register(): void
    {
        //
    }
}
