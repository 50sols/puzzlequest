<?php
namespace App\Jobs;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\{DB,Mail};
final class NotifySupport implements ShouldQueue {
    use Queueable;
    public int $tries=3;
    public function __construct(public string $ticketId){}
    public function handle(): void { $ticket=DB::table('support_tickets')->where('id',$this->ticketId)->first();if(!$ticket)return;Mail::raw('Support request '.$ticket->id."\nOpen the protected PuzzleQuest admin support module to respond.",fn($m)=>$m->to(config('puzzlequest.support_email'))->subject('PuzzleQuest support request')); }
}
