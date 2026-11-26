<?php
namespace App\Services;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\{Cache,Http};
final class Fcm {
    public function __construct(private Settings $settings){}
    public function credentials(): array {
        $credentials=$this->settings->get('firebase_credentials');
        if(!$credentials&&config('puzzlequest.firebase_credentials')){$path=realpath(config('puzzlequest.firebase_credentials'));if(!$path||str_starts_with($path,realpath(public_path())))throw new \RuntimeException('Firebase credential location must be private');$credentials=json_decode(file_get_contents($path),true,512,JSON_THROW_ON_ERROR);}
        if(!$credentials||($credentials['project_id']??'')!==config('puzzlequest.firebase_project')||empty($credentials['client_email'])||empty($credentials['private_key']))throw new \RuntimeException('FCM server credentials not configured');return $credentials;
    }
    public function accessToken(): string {
        $c=$this->credentials();$cache='fcm:oauth:'.hash('sha256',$c['client_email'].$c['private_key']);
        return Cache::remember($cache,3300,function()use($c){$jwt=JWT::encode(['iss'=>$c['client_email'],'scope'=>'https://www.googleapis.com/auth/firebase.messaging','aud'=>'https://oauth2.googleapis.com/token','iat'=>time(),'exp'=>time()+3600],$c['private_key'],'RS256');$response=Http::asForm()->timeout(10)->post('https://oauth2.googleapis.com/token',['grant_type'=>'urn:ietf:params:oauth:grant-type:jwt-bearer','assertion'=>$jwt])->throw()->json();if(empty($response['access_token']))throw new \RuntimeException('FCM OAuth token unavailable');return $response['access_token'];});
    }
    public function send(string $token,array $titleBody,array $data): array {
        $response=Http::withToken($this->accessToken())->timeout(12)->post('https://fcm.googleapis.com/v1/projects/'.config('puzzlequest.firebase_project').'/messages:send',['message'=>['token'=>$token,'notification'=>$titleBody,'data'=>array_map('strval',$data),'android'=>['priority'=>'normal'],'apns'=>['headers'=>['apns-priority'=>'5']]]]);
        return ['accepted'=>$response->successful(),'status'=>$response->status(),'name'=>$response->json('name'),'error'=>$response->json('error.status')];
    }
}
