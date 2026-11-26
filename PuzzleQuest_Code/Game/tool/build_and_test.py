#!/usr/bin/env python3
"""Developer-machine quality gate; refuses to say release is ready on failures."""
from pathlib import Path
import shutil, subprocess, sys, json, datetime
ROOT=Path(__file__).resolve().parents[1]
RESULT=ROOT/'BUILD_TEST_RESULTS.json'
results=[]

def step(label, command):
    print('\n---',label,command,flush=True)
    p=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                     text=True,errors='replace')
    results.append({'name':label,'exit_code':p.returncode,
                    'passed':p.returncode==0,'output_tail':p.stdout[-6000:]})
    print(p.stdout[-5000:])
    return p.returncode==0

def main():
    if not shutil.which('flutter'):
        results.append({'name':'Flutter SDK','passed':False,'reason':'Flutter not installed in this environment'})
    else:
        # Fail-fast: never label packaging complete when a prerequisite fails.
        checks=[('Flutter version',['flutter','--version']),
                ('Resolve dependencies',['flutter','pub','get']),
                ('Static analyzer',['flutter','analyze']),
                ('Unit tests',['flutter','test'])]
        for label,command in checks:
            if not step(label,command):break
        if results and all(x['passed'] for x in results):
            if sys.platform.startswith('linux'):
                step('Android APK',['flutter','build','apk','--release'])
                step('Android AAB',['flutter','build','appbundle','--release'])
            if sys.platform=='darwin':
                step('iOS unsigned build',['flutter','build','ios','--release','--no-codesign'])
    result={'timestamp_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'passed':bool(results) and all(x['passed'] for x in results),
            'checks':results}
    RESULT.write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
    if not result['passed']:
        raise SystemExit('Build gate blocked; see BUILD_TEST_RESULTS.json. No release success claimed.')
    print('Local build gate passed; device, API, FCM, AdMob, OAuth still need E2E validation.')

if __name__=='__main__':main()
