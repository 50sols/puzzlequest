<?php
declare(strict_types=1);

$base=dirname(__DIR__,3).'/puzzlequest_app';
if (!is_file($base.'/vendor/autoload.php')) {http_response_code(503);exit('Private Laravel application missing. Unzip from your cPanel account home.');}
if(is_file($base.'/storage/installed.lock')){http_response_code(404);exit('Installer locked');}
$secure=!empty($_SERVER['HTTPS'])&&strtolower((string)$_SERVER['HTTPS'])!=='off';
$local=in_array($_SERVER['REMOTE_ADDR']??'',['127.0.0.1','::1'],true);
if(!$secure&&!$local){http_response_code(426);exit('HTTPS is required before installation. Enable it in cPanel.');}
header('X-Content-Type-Options: nosniff');header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');header('Cache-Control: no-store, private');
header("Content-Security-Policy: default-src 'none'; style-src 'self'; script-src 'self'; form-action 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'");
// cPanel File Manager may extract static assets with mode 0600; Apache can reject
// /install/wizard.js with HTTP 403 while PHP itself is still runnable.
// Serve only the exact, trusted local wizard asset through the same PHP entry point.
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'GET' && ($_GET['asset'] ?? '') === 'wizard') {
    $script = __DIR__.'/wizard.js';
    if (!is_file($script) || is_link($script)) {
        http_response_code(503);
        header('Content-Type: text/plain; charset=utf-8');
        exit('Installer JavaScript is missing; verify the Setup ZIP extraction.');
    }
    header('Content-Type: application/javascript; charset=utf-8');
    readfile($script);
    exit;
}
ini_set('session.use_strict_mode','1');session_name('PQ_INSTALL');
session_set_cookie_params(['secure'=>$secure,'httponly'=>true,'samesite'=>'Strict']);session_start();
$_SESSION['csrf']??=bin2hex(random_bytes(32));

$private=$base.'/storage/app/private';
if(!is_dir($private))@mkdir($private,0700,true);
$keyFile=$private.'/install.key';
// Generate a fresh claim code on the server, NEVER embed a shared install secret in a release ZIP.
// Only the cPanel account owner can read this code from File Manager outside public/.
if(!is_file($keyFile)&&!is_link($keyFile)){
    $out=@fopen($keyFile,'x');
    if($out){@chmod($keyFile,0600);fwrite($out,bin2hex(random_bytes(24))."\n");fclose($out);}
}
$keyReady=is_file($keyFile)&&!is_link($keyFile)&&strlen(trim((string)@file_get_contents($keyFile)))>=40;
$checks=[];
if(is_file($base.'/vendor/autoload.php')){
    require $base.'/vendor/autoload.php';
    $checks=\App\Services\Installer::preflight($base);
}else $checks=['Production Composer dependencies'=>false];
$documentRoot=realpath($_SERVER['DOCUMENT_ROOT']??'')?:null;
$expected=realpath(dirname(__DIR__));
$checks['Document Root = /public_html/puzzlequest.50sols.com']=($documentRoot===$expected);
$checks['Laravel outside public_html']=(realpath($base)!==false&&!str_starts_with(realpath($base),$expected.DIRECTORY_SEPARATOR));
$checks['HTTPS']=$secure||$local;
$checks['Private install claim available']=$keyReady;
$passed=!in_array(false,$checks,true);
$error=null;$success=false;

if(($_SERVER['REQUEST_METHOD']??'GET')==='POST'){
    $action=(string)($_POST['action']??'install');
    $ip=hash('sha256',$_SERVER['REMOTE_ADDR']??'unknown');
    $counter=$private.'/install-attempts-'.$ip.'.json';
    $recent=is_file($counter)?json_decode((string)file_get_contents($counter),true):[];
    $recent=array_values(array_filter(is_array($recent)?$recent:[],fn($t)=>is_numeric($t)&&$t>time()-900));
    if(count($recent)>=8){http_response_code(429);$error='Too many failed installation attempts. Wait 15 minutes.';}
    elseif(!$keyReady||!hash_equals((string)$_SESSION['csrf'],(string)($_POST['csrf']??''))||!hash_equals(trim((string)file_get_contents($keyFile)),(string)($_POST['install_key']??''))){
        $recent[]=time();file_put_contents($counter,json_encode($recent),LOCK_EX);http_response_code(403);$error='Invalid installation claim code or session.';
    }else{
        try{
            if(!$passed)throw new \RuntimeException('Complete the cPanel preflight requirements first.');
            $d=['url'=>(string)($_POST['url']??''),'host'=>(string)($_POST['host']??''),
                'port'=>(int)($_POST['port']??3306),'database'=>(string)($_POST['database']??''),
                'username'=>(string)($_POST['username']??''),'password'=>(string)($_POST['password']??''),
                'admin_email'=>(string)($_POST['admin_email']??''),'admin_password'=>(string)($_POST['admin_password']??'')];
            if($action==='probe'){
                if(!preg_match('/^[A-Za-z0-9_]{1,64}$/D',$d['database'])||$d['port']<1||$d['port']>65535||$d['host']===''||$d['username']==='')throw new \RuntimeException('Invalid database parameters');
                $pdo=new \PDO('mysql:host='.$d['host'].';port='.$d['port'].';dbname='.$d['database'].';charset=utf8mb4',$d['username'],$d['password'],[\PDO::ATTR_ERRMODE=>\PDO::ERRMODE_EXCEPTION,\PDO::ATTR_TIMEOUT=>8]);
                $pdo->query('SELECT 1')->fetchColumn();
                $existing=$pdo->query('SHOW TABLES')->fetchColumn()!==false;
                if($existing&&!is_file($private.'/installing.json'))throw new \RuntimeException('Please choose a new empty database');
                header('Content-Type: application/json; charset=utf-8');echo json_encode(['ok'=>true,'message'=>'Database connection passed.']);exit;
            }
            if($action!=='install')throw new \RuntimeException('Unsupported installer action');
            (new \App\Services\Installer())->install($base,$d);$success=true;
            $_SESSION=[];session_destroy();
        }catch(\Throwable $e){
            // Deliberately do not include PDO/SMTP/server errors or connection details in web responses.
            @file_put_contents($private.'/install-error.json',json_encode(['at'=>gmdate('c'),'type'=>get_class($e),'phase'=>$action]),LOCK_EX);
            $error=$action==='probe'?'Could not connect. Check the database is empty, credentials and MySQL permissions.':'Installation could not finish. Correct cPanel settings and retry with the SAME database.';
            http_response_code(422);
        }
    }
    if($action==='probe'){
        header('Content-Type: application/json; charset=utf-8');echo json_encode(['ok'=>false,'message'=>$error]);exit;
    }
}
$h=fn($value)=>htmlspecialchars((string)$value,ENT_QUOTES|ENT_SUBSTITUTE,'UTF-8');
?><!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>PuzzleQuest — إعداد الموقع</title><link rel="stylesheet" href="/install/wizard.css"></head><body>
<main class="shell"><header class="hero"><span class="eyebrow">PUZZLEQUEST · ONE ZIP INSTALL</span><h1>إعداد لوحة اللعبة</h1><p>فحص الاستضافة ← ربط قاعدة البيانات ← إنشاء المدير ← تشغيل الموقع</p></header>
<?php if($success): ?>
<section class="panel" aria-live="polite"><h2>✓ تم التثبيت بنجاح</h2><p>تم إنشاء قاعدة البيانات وحساب المدير وقفل /install، وحذف مفتاح التثبيت.</p><p><a class="primary link" href="/admin/login">افتح لوحة الإدارة</a></p><p>الخطوة التالية: ضبط SMTP وFirebase وAdMob وCron من Settings، ثم مراجعة الصفحات القانونية. عدم تهيئتها لا يعني جاهزية النشر.</p></section>
<?php else: ?>
<?php if($error): ?><div class="error" role="alert"><?= $h($error) ?></div><?php endif; ?>
<div class="steps"><span class="current" data-indicator="1">١ · الفحص</span><span data-indicator="2">٢ · قاعدة البيانات</span><span data-indicator="3">٣ · المدير والتشغيل</span></div>
<form method="post" id="setup-form" autocomplete="off"><input type="hidden" name="csrf" value="<?= $h($_SESSION['csrf']) ?>"><input type="hidden" name="action" value="install">
<section class="panel step" data-step="1"><h2>١. متطلبات الاستضافة</h2>
<div class="checks"><?php foreach($checks as $name=>$ok): ?><div class="check <?= $ok?'ok':'bad' ?>"><?= $ok?'✓':'✕' ?> <?= $h($name) ?></div><?php endforeach; ?></div>
<p>لا يلزم تغيير Document Root. يجب فك ZIP مرة واحدة داخل مجلد الحساب الرئيسي بحيث يصبح <code>puzzlequest_app</code> بجوار <code>public_html</code>، وتكون ملفات الموقع داخل <code>public_html/puzzlequest.50sols.com</code>، وتفعيل HTTPS وإضافات PHP المطلوبة. قد يلزم إنشاء MySQL Database ومستخدمها من cPanel قبل المتابعة.</p>
<?php if($keyReady): ?><p>أنشأ النظام رمز تثبيت فريدًا خارج مجلد الويب. من cPanel File Manager افتح الملف <code>puzzlequest_app/storage/app/private/install.key</code> وانسخ الرمز. لا تشاركه ولا ترفعه إلى Git.</p>
<label>رمز ملكية التثبيت<input name="install_key" type="password" minlength="40" autocomplete="off" required></label>
<?php else: ?><div class="error">تعذّر إنشاء رمز التثبيت الخاص. امنح مجلد storage/app/private صلاحية الكتابة من cPanel وأعد التحميل.</div><?php endif; ?>
<div id="step-feedback" class="feedback" aria-live="polite"></div>
<noscript><div class="error">يحتاج معالج التثبيت JavaScript للانتقال بين الخطوات. فعّله في المتصفح.</div></noscript>
<div class="actions"><button type="button" data-next="2" <?= !$passed?'disabled':'' ?>>التالي ←</button></div></section>
<section class="panel step" data-step="2" hidden><h2>٢. اتصال MySQL / MariaDB</h2>
<div class="fields"><label>الرابط النهائي HTTPS<input name="url" value="https://puzzlequest.50sols.com" type="url" required></label><label>اسم خادم MySQL<input name="host" value="localhost" required></label><label>المنفذ<input name="port" type="number" min="1" max="65535" value="3306" required></label><label>اسم قاعدة البيانات<input name="database" required pattern="[A-Za-z0-9_]+"></label><label>اسم مستخدم قاعدة البيانات<input name="username" required></label><label>كلمة مرور قاعدة البيانات<input name="password" type="password" required></label></div>
<div id="probe-result" class="feedback" aria-live="polite">اختبر الاتصال قبل المتابعة.</div><div class="actions"><button type="button" class="secondary" data-prev="1">رجوع</button><button type="button" id="probe">اختبار الاتصال</button><button type="button" data-next="3" id="db-next" disabled>التالي ←</button></div></section>
<section class="panel step" data-step="3" hidden><h2>٣. حساب المدير والتثبيت</h2><div class="fields"><label>البريد الإلكتروني للمدير<input name="admin_email" type="email" required></label><label>كلمة مرور المدير (12–128 حرفًا)<input name="admin_password" type="password" minlength="12" maxlength="128" autocomplete="new-password" required></label></div>
<p>سيتم إنشاء خمس مراحل Green Valley، مع نسخ الأصول المضمّنة، وتفعيل حفظ التقدم والمكافآت وقفل المثبت عند النجاح. لن تُستخدم كلمة مرور افتراضية.</p>
<p>لن يحاول النظام إنشاء قاعدة البيانات من دون صلاحيات cPanel، ولن يفعّل Cron أو APNs أو SMTP تلقائيًا إذا كانت الاستضافة تمنع ذلك.</p>
<div class="actions"><button type="button" class="secondary" data-prev="2">رجوع</button><button type="submit" id="finish">إنهاء التثبيت</button></div></section>
</form>
<?php endif; ?>
<footer>تثبيت آمن بدون Composer أو Terminal على خادم الإنتاج. جميع الأسرار تُحفظ داخل puzzlequest_app خارج public_html/.</footer>
</main><script src="/install/?asset=wizard" defer></script></body></html>
