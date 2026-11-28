<?php
namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\{DB,Http,Mail};
use App\Services\Identity;

final class EmailGuestRegistrationTest extends TestCase {
    use RefreshDatabase;

    protected function setUp(): void {
        parent::setUp();
        Http::preventStrayRequests();
        Http::fake(['api.pwnedpasswords.com/*'=>Http::response('',200)]);
        Mail::fake();
    }

    private function payload(string $email='player@example.test'): array {
        return [
            'name'=>'Puzzle Player', 'email'=>$email,
            'password'=>'Secure-Player-84391',
            'password_confirmation'=>'Secure-Player-84391',
            'terms_accepted'=>true, 'terms_version'=>'1.0.0',
            'age_confirmed_13'=>true,
            'device_name'=>'Review Device', 'platform'=>'android',
        ];
    }

    public function test_guest_email_registration_reuses_player_id_and_preserves_wallet(): void {
        $guest=app(Identity::class)->guest(['device_name'=>'Test Device','platform'=>'android']);
        $id=$guest['player']['id'];
        $coins=$guest['player']['wallet']['coins'];
        $hints=$guest['player']['wallet']['hints'];

        $result=$this->postJson('/api/v1/auth/register', $this->payload(), [
            'Authorization'=>'Bearer '.$guest['access_token'],
        ])->assertCreated()->json();

        $this->assertSame($id,$result['player']['id']);
        $this->assertFalse($result['player']['is_guest']);
        $this->assertSame($coins,$result['player']['wallet']['coins']);
        $this->assertSame($hints,$result['player']['wallet']['hints']);
        $this->assertSame(1,DB::table('users')->where('id',$id)->count());
        $this->assertSame(1,DB::table('users')->count());
        $this->assertSame(1,DB::table('consents')->where('user_id',$id)->count());
        $this->assertNotEmpty($result['verification']['challenge_id']);
    }

    public function test_invalid_guest_token_does_not_silently_create_another_account(): void {
        $this->postJson('/api/v1/auth/register',$this->payload(),[
            'Authorization'=>'Bearer invalid-guest-token',
        ])->assertUnauthorized();
        $this->assertSame(0,DB::table('users')->count());
    }

    public function test_duplicate_email_and_confirmation_validation(): void {
        $this->postJson('/api/v1/auth/register',$this->payload())->assertCreated();
        $this->postJson('/api/v1/auth/register',$this->payload())->assertStatus(409);
        $invalid=$this->payload('new@example.test');
        $invalid['password_confirmation']='different';
        $this->postJson('/api/v1/auth/register',$invalid)->assertUnprocessable()
            ->assertJsonValidationErrors(['password']);
        $this->assertSame(1,DB::table('users')->count());
    }
}
