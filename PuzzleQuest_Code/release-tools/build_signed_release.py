#!/usr/bin/env python3
"""CI/build-machine Ed25519 ZIP builder for the existing PuzzleQuest Updates.php verifier.
Never put the signing key inside a ZIP/repository or production public directory.
"""
from __future__ import annotations
import argparse, base64, hashlib, json, os, pathlib, re, subprocess, zipfile

PAYLOAD = [
    'app/Http/Controllers/AdminController.php',
    'app/Http/Controllers/GameController.php',
    'app/Http/Controllers/StudioApiController.php',
    'app/Http/Controllers/StudioPairingController.php',
    'app/Http/Middleware/StudioToken.php',
    'app/Services/Game.php',
    'app/Services/StudioDocuments.php',
    'app/Services/Installer.php',
    'app/Services/Updates.php',
    'bootstrap/app.php',
    'config/puzzlequest.php',
    'database/migrations/2026_11_26_000004_create_studio_remote_management.php',
    'resources/views/admin/module.blade.php',
    'resources/views/admin/studio-pairing.blade.php',
    'routes/api.php',
    'routes/web.php',
]

def sha(data):return hashlib.sha256(data).hexdigest()

def sign_php(data,keyfile):
    script="""$secret=base64_decode(trim(file_get_contents(getenv('PQ_RELEASE_KEY_FILE'))),true);
if(strlen($secret)!==SODIUM_CRYPTO_SIGN_SECRETKEYBYTES)exit(5);
$bytes=stream_get_contents(STDIN);echo base64_encode(sodium_crypto_sign_detached($bytes,$secret));"""
    env=os.environ.copy();env['PQ_RELEASE_KEY_FILE']=str(keyfile)
    proc=subprocess.run(['php','-r',script],input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,timeout=30)
    if proc.returncode:raise RuntimeError('PHP Ed25519 signing failed (sodium required)')
    return proc.stdout.decode('ascii')

def build(root,out,private_key,from_version,to_version,source_sha):
    if not re.fullmatch(r'\d+\.\d+\.\d+',from_version) or not re.fullmatch(r'\d+\.\d+\.\d+',to_version):raise ValueError('Only MAJOR.MINOR.PATCH versions supported')
    files={}
    for name in PAYLOAD:
        path=root/name
        if not path.is_file() or path.is_symlink():raise ValueError('Missing/unsafe file: '+name)
        files[name]=sha(path.read_bytes())
    release={'format':'puzzlequest-signed-update-v1','version':to_version,'from_version':from_version,'min_supported_version':from_version,
      'php_min':'8.3.0','git_sha':None,'git_sha_note':'Uploaded source is a RAR, no Git revision provided',
      'source_archive_sha256':source_sha,'composer_lock_sha256':sha((root/'composer.lock').read_bytes()),
      'dependencies_changed':False,'required_extensions':['pdo_mysql','gd','dom','mbstring','sodium','zip','openssl'],
      'migrations':['database/migrations/2026_11_26_000004_create_studio_remote_management.php'],
      'notes_ar':'إدارة عن بعد للعوالم والمراحل والقرية والمجموعات والفعاليات والصور، مع محرر بصري ومسودات وإصدارات منشورة وTokens آمنة. لا تغيّر أرصدة اللاعبين أو .env أو ملفاتهم.',
      'test_status':'static_checks_and_python_unit_tests_only; PHP feature DB & production upgrade not run',
      'files':files}
    manifest=(json.dumps(release,ensure_ascii=False,indent=2,sort_keys=True)+'\n').encode('utf-8')
    sig=sign_php(manifest,private_key)
    name=f'PuzzleQuest-Update-v{to_version}-from-v{from_version}.zip';dest=out/name
    with zipfile.ZipFile(dest,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=8) as z:
        z.writestr('release.json',manifest);z.writestr('release.sig',sig+'\n')
        for filename in sorted(files):z.write(root/filename,'payload/'+filename)
    (out/(name+'.sha256')).write_text(sha(dest.read_bytes())+'  '+name+'\n')
    return dest,release

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);p.add_argument('--private-key-file',type=pathlib.Path,required=True);p.add_argument('--from-version',required=True);p.add_argument('--version',default='1.1.0');p.add_argument('--source-archive-sha256',required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    path,m=build(a.source,a.output,a.private_key_file,a.from_version,a.version,a.source_archive_sha256);print(path,sha(path.read_bytes()),len(m['files']))
