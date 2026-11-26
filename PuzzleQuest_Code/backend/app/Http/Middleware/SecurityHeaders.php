<?php
namespace App\Http\Middleware;
use Closure;
final class SecurityHeaders {
    public function handle($request, Closure $next) {
        if(config('puzzlequest.enforce_tls') && app()->environment('production') && !$request->secure()) return response('HTTPS required',426);
        $r=$next($request);
        $r->headers->set('X-Content-Type-Options','nosniff'); $r->headers->set('X-Frame-Options','DENY'); $r->headers->set('Referrer-Policy','no-referrer');
        $r->headers->set('Content-Security-Policy',"default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
        if($request->secure()) $r->headers->set('Strict-Transport-Security','max-age=31536000');
        if($request->is('api/*')||$request->is('admin*'))$r->headers->set('Cache-Control','no-store');
        return $r;
    }
}
