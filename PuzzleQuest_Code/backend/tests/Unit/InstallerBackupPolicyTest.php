<?php
namespace Tests\Unit;

use App\Services\{Installer,SafeZip};
use PHPUnit\Framework\TestCase;

final class InstallerBackupPolicyTest extends TestCase {
    public function test_environment_rejects_newlines_and_invalid_keys(): void {
        $this->expectException(\RuntimeException::class);
        Installer::environment(['DB_HOST'=>"localhost\nAPP_DEBUG=true"]);
    }
    public function test_installer_environment_quotes_special_characters_without_newline(): void {
        $env=Installer::environment(['DB_PASSWORD'=>'abc$"\\def']);
        $this->assertStringContainsString('DB_PASSWORD=', $env);
        $this->assertStringNotContainsString("\nAPP_DEBUG",$env);
    }
    public function test_zip_traversal_and_windows_paths_are_rejected(): void {
        $zip=new SafeZip();
        foreach(['../secrets','.env/../foo','C:/windows','dir\\script.php'] as $path) {
            try {$zip->path($path);$this->fail('Unsafe path accepted: '.$path);}
            catch (\RuntimeException $e) {$this->assertNotSame('', $e->getMessage());}
        }
    }
}
