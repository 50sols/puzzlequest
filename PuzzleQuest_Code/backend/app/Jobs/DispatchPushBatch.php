<?php
namespace App\Jobs;
use Illuminate\Contracts\Queue\{ShouldQueue,ShouldBeUnique};
use Illuminate\Foundation\Queue\Queueable;
final class DispatchPushBatch implements ShouldQueue,ShouldBeUnique {
    use Queueable;
    public int $tries=1;public int $timeout=45;public int $uniqueFor=55;
    public function handle(\App\Services\Notifications $notifications): void {$notifications->dispatchDue(3);}
}
