<?php
namespace App\Support;
final class Json {
    public static function read(mixed $value, mixed $default = []): mixed { return is_string($value) ? (json_decode($value, true, 512, JSON_THROW_ON_ERROR) ?? $default) : ($value ?? $default); }
    public static function encode(mixed $value): string { return json_encode($value, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR); }
    public static function fail(string $code, int $status=422, array $context=[]): never { abort(response()->json(['error'=>$code,'context'=>$context],$status)); }
}
