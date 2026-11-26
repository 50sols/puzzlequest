"""HTTPS-only, scoped PuzzleQuest Studio API client. Tokens are never written to disk."""
from __future__ import annotations
import json
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.error import HTTPError, URLError
from uuid import uuid4
from http.client import RemoteDisconnected
from zipfile import ZipFile, BadZipFile
import socket


class StudioApiError(RuntimeError):
    pass


class _DenyRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise StudioApiError('Unexpected server redirect; verify the dashboard URL and HTTPS.')


class StudioApiClient:
    def __init__(self, base_url: str, token: str):
        u = urlsplit(base_url.strip().rstrip('/'))
        if u.scheme != 'https' or not u.hostname or u.username or u.password or u.query or u.fragment or (u.path not in ('', '/')):
            raise StudioApiError('Use only a clean HTTPS origin, e.g. https://puzzlequest.50sols.com')
        if len(token) != 64 or any(c not in '0123456789abcdef' for c in token):
            raise StudioApiError('Paste the 64-character Studio pairing token, not your admin password.')
        self.origin = f'https://{u.netloc}'
        self._token = token
        self._opener = build_opener(_DenyRedirect())

    def _request(self, method: str, path: str, data: dict | None = None, *, file: Path | None = None, field='image'):
        if not path.startswith('/') or '//' in path or '..' in path or '?' in path:
            raise StudioApiError('Invalid API path')
        headers = {'Accept':'application/json', 'Authorization':f'Bearer {self._token}', 'User-Agent':'PuzzleQuestStudio/1.1'}
        body = None
        if file is not None:
            if not file.is_file(): raise StudioApiError('Select a real ZIP/image file')
            if file.stat().st_size > 128 * 1024 * 1024: raise StudioApiError('File exceeds the remote upload limit')
            boundary = 'pq'+uuid4().hex
            filename = file.name.replace('"','_').replace('\r','_').replace('\n','_')
            kind = 'application/zip' if field=='archive' else 'application/octet-stream'
            body = (f'--{boundary}\r\nContent-Disposition: form-data; name="{field}"; filename="{filename}"\r\nContent-Type: {kind}\r\n\r\n').encode()+file.read_bytes()+f'\r\n--{boundary}--\r\n'.encode()
            headers['Content-Type'] = 'multipart/form-data; boundary='+boundary
        elif data is not None:
            body = json.dumps(data, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
            headers['Content-Type'] = 'application/json'
        request = Request(self.origin+'/api/studio/v1'+path, data=body, headers=headers, method=method)
        try:
            with self._opener.open(request, timeout=180 if file is not None else 30) as response:
                raw=response.read(2 * 1024 * 1024)
                return json.loads(raw.decode('utf-8'))
        except HTTPError as exc:
            raw=exc.read(8192)
            try:
                err=json.loads(raw.decode('utf-8'))
                detail = err.get('message') or err.get('error') or str(err.get('errors',''))
            except Exception:
                detail = f'HTTP {exc.code}'
            raise StudioApiError(f'HTTP {exc.code}: {detail}') from None
        except URLError as exc:
            raise StudioApiError(f'Connection failed (HTTPS/network): {exc.reason}') from None
        except (RemoteDisconnected, ConnectionResetError, BrokenPipeError, TimeoutError, socket.timeout, OSError) as exc:
            action = ('The server closed the connection during ZIP/image upload. This DOES NOT prove the import failed. '
                      'Open Refresh Revisions and check for a newly-created draft before trying again. '
                      'If none appears, check PHP-FPM/hosting request timeouts and server error logs.'
                      if file is not None else 'Remote connection interrupted; check the server HTTPS endpoint.')
            raise StudioApiError(action + f' ({type(exc).__name__})') from None
        except (ValueError, UnicodeDecodeError):
            raise StudioApiError('Server did not return valid JSON. Check that the API update is installed.') from None

    def get(self,path): return self._request('GET',path)
    def post(self,path,data=None): return self._request('POST',path,data or {})
    def patch(self,path,data): return self._request('PATCH',path,data)
    def upload(self,path,file,field):return self._request('POST',path,file=Path(file),field=field)
    def schema(self):return self.get('/schema')
    def worlds(self):return self.get('/worlds')['items']
    def levels(self):return self.get('/levels')['items']
    def revisions(self):return self.get('/revisions')['items']
    def documents(self,kind):return self.get('/documents/'+kind)['items']
    def media(self):return self.get('/media')['items']
    def preflight_import(self, path):
        """Read JSON and verify immutable identity against live backend, before transferring bytes.

        This is intentionally read-only. Unknown worlds are never auto-created or guessed.
        """
        from .laravel_import import ID_PATTERN, CODE_PATTERN
        try:
            with ZipFile(path) as z:
                meta=json.loads(z.read('level.json'))
        except (OSError, BadZipFile, KeyError, ValueError, TypeError) as exc:
            raise StudioApiError('ZIP missing valid root level.json: '+str(exc)) from None
        world=meta.get('world_id');lid=meta.get('level_id');code=meta.get('display_code')
        title=meta.get('title')
        if not isinstance(world,str) or not isinstance(lid,str) or not ID_PATTERN.fullmatch(lid) or not isinstance(code,str) or not CODE_PATTERN.fullmatch(code) or not isinstance(title,dict) or not all(isinstance(title.get(locale),str) and title[locale].strip() for locale in ('ar','en')):
            raise StudioApiError('ZIP level identity/title invalid; use Laravel Export with Arabic and English titles.')
        worlds=self.worlds()
        world_ids=[row['id'] for row in worlds]
        if world not in world_ids:
            hint=world.replace('-','_')
            suggestion=(f' Suggested world_id: {hint}.' if hint in world_ids else '')
            raise StudioApiError('ZIP world_id '+repr(world)+' is NOT in server worlds table. '
                                 'Available server world IDs: '+', '.join(world_ids[:15])+'.'+suggestion+' Fix/re-export ZIP before upload.')
        levels=self.levels()
        for row in levels:
            if row['id']==lid:
                if row['world_id']!=world or row['display_code']!=code:
                    raise StudioApiError('Existing level '+lid+' has immutable world_id/display_code mismatch. Do not replace existing published content.')
            elif row['display_code']==code:
                raise StudioApiError('Display code '+code+' is already used by '+row['id']+'; choose a new level number.')
        return meta

    def import_zip(self,path):
        self.preflight_import(path)
        return self.upload('/revisions/import',path,'archive')
    def upload_image(self,path):return self.upload('/media',path,'image')
