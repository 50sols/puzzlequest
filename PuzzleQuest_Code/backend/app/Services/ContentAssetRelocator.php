<?php
namespace App\Services;

/** One-time, non-destructive transfer from a legacy private public/ to the cPanel document root. */
final class ContentAssetRelocator
{
    /** @param iterable<array{asset_prefix:string,hashes:array<string,string>}> $revisions */
    public static function copyMissing(iterable $revisions, string $legacyRoot, string $documentRoot): array
    {
        if (is_link($legacyRoot) || is_link($documentRoot)) {
            throw new \RuntimeException('Content root must not be a symlink');
        }
        $from = realpath($legacyRoot);
        $to = realpath($documentRoot);
        if ($to === false || !is_dir($to) || !is_file($to.'/index.php')) {
            throw new \RuntimeException('Fixed public document root not found');
        }
        if ($from !== false && $from === $to) return ['copied'=>0, 'verified'=>0];
        $counts = ['copied'=>0, 'verified'=>0];
        foreach ($revisions as $revision) {
            $prefix = $revision['asset_prefix'] ?? '';
            if (!is_string($prefix) || !preg_match('~\Acontent/[a-z0-9_]{3,100}/[a-zA-Z0-9_-]{10,128}\z~D', $prefix)) {
                throw new \RuntimeException('Invalid persisted asset prefix; no files altered');
            }
            $hashes = $revision['hashes'] ?? null;
            if (!is_array($hashes) || $hashes === []) throw new \RuntimeException('Missing revision checksums');
            foreach ($hashes as $file => $digest) {
                if (!is_string($file) || !preg_match('~\A[a-zA-Z0-9_-][a-zA-Z0-9_.\/-]{0,240}\z~D', $file)
                    || str_contains($file, '..') || str_contains($file, '//') || str_starts_with($file, '/')) {
                    throw new \RuntimeException('Invalid asset name in revision');
                }
                if (!preg_match('/\.(?:png|jpe?g|webp|svg|json)\z/iD', $file)) {
                    throw new \RuntimeException('Unsupported asset extension in revision');
                }
                if (!is_string($digest) || !preg_match('/\A[a-f0-9]{64}\z/D', $digest)) {
                    throw new \RuntimeException('Invalid asset checksum');
                }
                $relative = $prefix.'/'.$file;
                $destination = $to.'/'.$relative;
                // Never follow existing symlinks, even in an intermediate folder.
                self::inspectParents($to, $relative, false);
                if (is_file($destination)) {
                    if (is_link($destination) || !hash_equals($digest, hash_file('sha256', $destination))) {
                        throw new \RuntimeException('Conflicting public asset: '.$relative);
                    }
                    $counts['verified']++;
                    continue;
                }
                if ($from === false) throw new \RuntimeException('Legacy content unavailable: '.$relative);
                self::inspectParents($from, $relative, false);
                $source = $from.'/'.$relative;
                if (!is_file($source) || is_link($source) || !hash_equals($digest, hash_file('sha256', $source))) {
                    throw new \RuntimeException('Missing or corrupt legacy asset: '.$relative);
                }
                self::inspectParents($to, $relative, true);
                $tmp = $destination.'.pq-copy-'.bin2hex(random_bytes(8));
                try {
                    if (!copy($source, $tmp) || !hash_equals($digest, hash_file('sha256', $tmp))) {
                        throw new \RuntimeException('Asset copy verification failed: '.$relative);
                    }
                    @chmod($tmp, 0644);
                    if (file_exists($destination) || is_link($destination) || !rename($tmp, $destination)) {
                        throw new \RuntimeException('Cannot safely finalize asset: '.$relative);
                    }
                    $counts['copied']++;
                } finally {
                    if (is_file($tmp)) unlink($tmp);
                }
            }
        }
        return $counts;
    }

    private static function inspectParents(string $root, string $relative, bool $create): void
    {
        $parts = explode('/', $relative);
        array_pop($parts); // Only directories; the file itself is checked separately.
        $current = $root;
        foreach ($parts as $part) {
            if ($part === '' || $part === '.' || $part === '..') throw new \RuntimeException('Unsafe content folder');
            $current .= '/'.$part;
            if (is_link($current)) throw new \RuntimeException('Symlink in content path');
            if (!is_dir($current)) {
                if (!$create) {
                    // A destination tree not yet created is fine, but any existing ancestor still gets checked.
                    if (file_exists($current)) throw new \RuntimeException('Unexpected file in content path');
                    continue;
                }
                if (file_exists($current) || !@mkdir($current, 0755)) throw new \RuntimeException('Cannot create content directory');
            }
        }
    }
}
