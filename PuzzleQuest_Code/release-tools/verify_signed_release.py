#!/usr/bin/env python3
"""Release binary verification, including a real PHP sodium signature check."""
import base64,hashlib,json,os,pathlib,re,subprocess,sys,zipfile

def verify(path,key):
    with zipfile.ZipFile(path,'r') as z:
        names=z.namelist();assert len(names)==len(set(names)),'Duplicate archive entries'
        assert all('..' not in pathlib.PurePosixPath(p).parts and not p.startswith('/') and '\\' not in p for p in names),'Unsafe ZIP paths'
        assert set(['release.json','release.sig']).issubset(names)
        manifest=z.read('release.json');sig=z.read('release.sig').strip()
        m=json.loads(manifest)
        assert re.fullmatch(r'\d+\.\d+\.\d+',m['version'])
        expected={'release.json','release.sig'}|{'payload/'+p for p in m['files']}
        assert set(names)==expected,'Unexpected files in update archive'
        for p,expectedhash in m['files'].items():
            assert not p.endswith(('.ttf','.otf','.woff','.woff2'))
            assert re.fullmatch('[a-f0-9]{64}',expectedhash)
            assert hashlib.sha256(z.read('payload/'+p)).hexdigest()==expectedhash,'Checksum mismatch '+p
        script="""$key=base64_decode(trim(file_get_contents(getenv('PQ_PUBLIC_KEY_FILE'))),true);
$line=fgets(STDIN);$msg=base64_decode(trim($line));$sig=base64_decode(trim(fgets(STDIN)),true);
if(!$key||!$sig||!sodium_crypto_sign_verify_detached($sig,$msg,$key))exit(1);"""
        env=os.environ.copy();env['PQ_PUBLIC_KEY_FILE']=str(key)
        p=subprocess.run(['php','-r',script],input=base64.b64encode(manifest)+b'\n'+sig+b'\n',env=env,capture_output=True,timeout=30)
        assert p.returncode==0,'Ed25519 signature invalid'
        return m

if __name__=='__main__':
    if len(sys.argv)!=3:raise SystemExit('Usage: verify_signed_release.py <zip> <public-key-file>')
    m=verify(pathlib.Path(sys.argv[1]),pathlib.Path(sys.argv[2]));print('VERIFIED',m['version'],m['from_version'],len(m['files']))
