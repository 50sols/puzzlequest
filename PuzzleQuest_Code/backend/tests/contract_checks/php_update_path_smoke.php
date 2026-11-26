<?php
// Dependency-free updater path-contract smoke test; safe to run on developer machine.
namespace {
    $home = sys_get_temp_dir().'/pq-updates-test-'.bin2hex(random_bytes(5));
    mkdir($home.'/puzzlequest_app',0755,true);
    mkdir($home.'/public_html/puzzlequest.50sols.com',0755,true);
    file_put_contents($home.'/public_html/puzzlequest.50sols.com/index.php','<?php');
    function base_path(?string $part=null): string {global $home;return $home.'/puzzlequest_app'.($part?'/'.$part:'');}
    function public_path(?string $part=null): string {global $home;return $home.'/public_html/puzzlequest.50sols.com'.($part?'/'.$part:'');}
}
namespace App\Services {
    class SafeZip {
        public function path(string $name): void {
            if (!$name || str_contains($name,'\\') || str_starts_with($name,'/') ||
                preg_match('~(^|/)\.\.?(/|$)~',$name)) throw new \RuntimeException('Unsafe archive path');
        }
    }
    class Backups {}
}
namespace {
    require dirname(__DIR__,2).'/app/Services/Updates.php';
    $up = new \App\Services\Updates(new \App\Services\SafeZip(),new \App\Services\Backups());
    $method = new \ReflectionMethod($up,'destination');
    assert($method->invoke($up,'public/content/example/master.png')===public_path('content/example/master.png'));
    assert($method->invoke($up,'app/Services/Foo.php')===base_path('app/Services/Foo.php'));
    foreach (['public/../.env','public/install/index.php','app/../../public/index.php','storage/app/private/db'] as $bad) {
        try {$method->invoke($up,$bad);throw new \Exception('Unsafe update path accepted: '.$bad);}
        catch (\RuntimeException $e) {}
    }
    mkdir(public_path('unsafe'),0755);
    symlink(base_path(),public_path('unsafe/link'));
    try {$method->invoke($up,'public/unsafe/link/a.png');throw new \Exception('Symlink accepted');}
    catch (\RuntimeException $e) {}
    unlink(public_path('unsafe/link'));rmdir(public_path('unsafe'));
    rmdir(public_path('content/example'));rmdir(public_path('content'));
    rmdir(base_path('app/Services'));rmdir(base_path('app'));
    unlink(public_path('index.php'));rmdir(public_path());rmdir($home.'/public_html');
    rmdir(base_path());rmdir($home);
    echo "Updater public/private path checks PASS\n";
}
