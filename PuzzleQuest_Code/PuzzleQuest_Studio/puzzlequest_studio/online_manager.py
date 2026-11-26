"""Desktop administration for published PuzzleQuest content over scoped HTTPS token API."""
from __future__ import annotations
import json
import queue
import threading
import tkinter as tk
from datetime import datetime, timedelta, timezone
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from .remote import StudioApiClient, StudioApiError

BG='#111827';FG='#e5e7eb';ACCENT='#1fac83'
KINDS=['collection','level_group','world_art','village_scene','village_item','event','mission','achievement','banner','story']

class OnlineManager(tk.Toplevel):
    def __init__(self,parent):
        super().__init__(parent)
        self.title('PuzzleQuest Studio • Online Content Manager v1.1.2')
        self.geometry('1220x890');self.minsize(1000,700);self.configure(bg=BG)
        self.client=None
        self.jobs=queue.Queue();self.busy=False
        self.world_rows=[];self.level_rows=[];self.doc_rows=[];self.media_rows=[];self.rev_rows=[]
        self.selected_doc=None;self.selected_world=None;self.selected_level=None
        self.origin=tk.StringVar(value='https://puzzlequest.50sols.com')
        self.token=tk.StringVar()
        self.connection=tk.StringVar(value='Disconnected — pair in Admin → Studio')
        self.status=tk.StringVar(value='Connect before editing. No credentials are saved to disk.')
        self._build()
        self.after(100,self._poll)

    def _job(self,description,func,callback=None):
        if self.busy:
            messagebox.showinfo('Working','Finish the current request first.',parent=self);return
        if not self.client:
            messagebox.showerror('Not connected','Connect to the dashboard first.',parent=self);return
        self.busy=True;self.status.set(description)
        def worker():
            try:self.jobs.put((callback,func(),None))
            except Exception as e:self.jobs.put((callback,None,e))
        threading.Thread(target=worker,daemon=True).start()

    def _poll(self):
        try:
            while True:
                callback,value,error=self.jobs.get_nowait();self.busy=False
                if error:
                    self.status.set('Request failed')
                    messagebox.showerror('PuzzleQuest API',str(error)[:900],parent=self)
                else:
                    self.status.set('Operation completed • server response received')
                    if callback:callback(value)
        except queue.Empty:pass
        if self.winfo_exists():self.after(100,self._poll)

    def _line(self,parent,caption,var,width=24):
        frame=ttk.Frame(parent);ttk.Label(frame,text=caption).pack(side='left',padx=(0,6))
        ttk.Entry(frame,textvariable=var,width=width).pack(side='left',fill='x',expand=True)
        return frame
    def _action(self,parent,text,callback):ttk.Button(parent,text=text,command=callback).pack(side='left',padx=4,pady=5)
    def _json(self,text):
        try:return json.loads(text.get('1.0','end-1c'))
        except json.JSONDecodeError as e:raise StudioApiError(f'Invalid JSON: {e.msg} at line {e.lineno}')
    def _confirm(self,text):return messagebox.askyesno('Confirm operation',text,parent=self)

    def _build(self):
        style=ttk.Style(self);style.theme_use('clam')
        style.configure('TFrame',background=BG);style.configure('TLabel',background=BG,foreground=FG)
        style.configure('TButton',padding=7);style.configure('TNotebook',background=BG);style.configure('TNotebook.Tab',padding=(12,7))
        style.configure('Treeview',rowheight=24,background='#1d2938',foreground='#f0f3f7',fieldbackground='#1d2938')
        header=ttk.Frame(self);header.pack(fill='x',padx=15,pady=(12,8))
        ttk.Label(header,text='Remote Studio API  •  HTTPS',font=('Segoe UI',14,'bold')).pack(anchor='w')
        row=ttk.Frame(header);row.pack(fill='x',pady=6)
        self._line(row,'Server',self.origin,35).pack(side='left',fill='x',expand=True)
        ttk.Label(row,text='Token').pack(side='left',padx=(10,4))
        ttk.Entry(row,textvariable=self.token,show='•',width=36).pack(side='left',padx=4)
        ttk.Button(row,text='Connect',command=self.connect).pack(side='left',padx=5)
        ttk.Button(row,text='Disconnect',command=self.disconnect).pack(side='left',padx=5)
        ttk.Label(header,textvariable=self.connection).pack(anchor='w')
        self.tabs=ttk.Notebook(self);self.tabs.pack(fill='both',expand=True,padx=12,pady=8)
        self._world_tab();self._level_tab();self._revisions_tab();self._documents_tab();self._media_tab()
        ttk.Label(self,textvariable=self.status).pack(fill='x',padx=12,pady=10)

    def connect(self):
        try:self.client=StudioApiClient(self.origin.get(),self.token.get().strip())
        except Exception as exc:return messagebox.showerror('Configuration',str(exc),parent=self)
        self._job('Checking API and token',self.client.schema,self._connected)
    def _connected(self,result):
        self.connection.set(f'Connected • Backend {result["backend_version"]} • Role {result["role"]}')
        self.token.set('')  # do not keep a second Tk variable copy of the token
        self._job('Fetching online world/level/artwork/catalog data',
            lambda:{'worlds':self.client.worlds(),'levels':self.client.levels(),
                    'documents':self.client.documents(self.kind.get()),'media':self.client.media(),
                    'revisions':self.client.revisions()},self._all_loaded)
    def _all_loaded(self,bundle):
        self._world_result(bundle['worlds']);self._level_result(bundle['levels'])
        self._documents_result(bundle['documents']);self._media_result(bundle['media'])
        self._revision_result(bundle['revisions'])

    def disconnect(self):
        self.client=None;self.token.set('');self.connection.set('Disconnected');self.status.set('Token cleared from the client object')

    def _tree(self,parent,columns):
        tree=ttk.Treeview(parent,columns=columns,show='headings',height=12,selectmode='browse')
        for name in columns:tree.heading(name,text=name);tree.column(name,width=130,stretch=True)
        tree.pack(fill='both',expand=True,padx=8,pady=7);return tree
    def _refresh_tree(self,tree,rows,cols):
        tree.delete(*tree.get_children())
        for i,row in enumerate(rows):tree.insert('',tk.END,iid=str(i),values=[row.get(x,'') for x in cols])

    def _world_tab(self):
        p=ttk.Frame(self.tabs);self.tabs.add(p,text='Worlds')
        self.world_cols=('id','position','published');self.world_tree=self._tree(p,self.world_cols)
        self.world_tree.bind('<<TreeviewSelect>>',self._select_world)
        f=ttk.Frame(p);f.pack(fill='x',padx=10)
        self.w_id=tk.StringVar();self.w_ar=tk.StringVar();self.w_en=tk.StringVar();self.w_position=tk.StringVar(value='1');self.w_published=tk.BooleanVar()
        for label,var in [('World ID',self.w_id),('Arabic',self.w_ar),('English',self.w_en),('Position',self.w_position)]:self._line(f,label,var).pack(fill='x',pady=3)
        ttk.Checkbutton(f,text='Published (requires a published level)',variable=self.w_published).pack(anchor='w')
        row=ttk.Frame(f);row.pack(fill='x')
        for text,fn in [('Refresh Worlds',self.refresh_worlds),('Create Draft World',self.create_world),('Update World',self.save_world)]:self._action(row,text,fn)
    def refresh_worlds(self):
        if not self.client:return messagebox.showerror('Disconnected','Connect to the dashboard first.',parent=self)
        self._job('Fetching worlds',self.client.worlds,self._world_result)
    def _world_result(self,rows):
        self.world_rows=rows;self._refresh_tree(self.world_tree,rows,self.world_cols)
        ids=[r['id'] for r in rows]
        self.fix_world_combo['values']=ids
        if ids and self.fix_world_id.get() not in ids:
            self.fix_world_id.set('green_valley' if 'green_valley' in ids else ids[0])
    def _select_world(self,*_):
        sel=self.world_tree.selection()
        if not sel:return
        self.selected_world=self.world_rows[int(sel[0])];w=self.selected_world
        self.w_id.set(w['id']);self.w_ar.set(w['title']['ar']);self.w_en.set(w['title']['en']);self.w_position.set(str(w['position']));self.w_published.set(w['published'])
    def _world_payload(self):return dict(title={'ar':self.w_ar.get().strip(),'en':self.w_en.get().strip()},position=int(self.w_position.get()),published=self.w_published.get())
    def create_world(self):
        try:p=self._world_payload();p['id']=self.w_id.get().strip();p.pop('published')
        except ValueError:return messagebox.showerror('Invalid','Position must be numeric',parent=self)
        self._job('Creating draft world',lambda:self.client.post('/worlds',p),lambda _:self.refresh_worlds())
    def save_world(self):
        if not self.selected_world:return messagebox.showerror('Select','Select a world',parent=self)
        try:p=self._world_payload()
        except ValueError:return messagebox.showerror('Invalid','Position must be numeric',parent=self)
        if p['published']!=self.selected_world['published'] and not self._confirm('Change world publication state?'):return
        self._job('Updating world',lambda:self.client.patch('/worlds/'+self.selected_world['id'],p),lambda _:self.refresh_worlds())

    def _level_tab(self):
        p=ttk.Frame(self.tabs);self.tabs.add(p,text='Levels')
        self.level_cols=('id','world_id','display_code','position','published');self.level_tree=self._tree(p,self.level_cols)
        self.level_tree.bind('<<TreeviewSelect>>',self._select_level)
        f=ttk.Frame(p);f.pack(fill='x',padx=10)
        self.l_id=tk.StringVar();self.l_world=tk.StringVar();self.l_code=tk.StringVar();self.l_position=tk.StringVar(value='1');self.l_ar=tk.StringVar();self.l_en=tk.StringVar();self.l_prev=tk.StringVar()
        for label,var in [('Backend Level ID',self.l_id),('World ID',self.l_world),('Display code',self.l_code),('Order',self.l_position),('Title AR',self.l_ar),('Title EN',self.l_en),('Previous Backend Level ID',self.l_prev)]:self._line(f,label,var).pack(fill='x',pady=2)
        row=ttk.Frame(f);row.pack(fill='x')
        for text,fn in [('Refresh Levels',self.refresh_levels),('Create Draft',self.create_level),('Save Metadata',self.save_level),('Unpublish',self.unpublish_level)]:self._action(row,text,fn)
    def refresh_levels(self):
        if not self.client:return messagebox.showerror('Disconnected','Connect to the dashboard first.',parent=self)
        self._job('Fetching levels',self.client.levels,self._level_result)
    def _level_result(self,rows):self.level_rows=rows;self._refresh_tree(self.level_tree,rows,self.level_cols)
    def _select_level(self,*_):
        sel=self.level_tree.selection()
        if not sel:return
        l=self.level_rows[int(sel[0])];self.selected_level=l
        for var,k in [(self.l_id,'id'),(self.l_world,'world_id'),(self.l_code,'display_code'),(self.l_position,'position'),(self.l_prev,'previous_level_id')]:var.set(str(l.get(k)or''))
        self.l_ar.set(l['title']['ar']);self.l_en.set(l['title']['en'])
    def _level_payload(self):return dict(world_id=self.l_world.get().strip(),display_code=self.l_code.get().strip(),position=int(self.l_position.get()),title={'ar':self.l_ar.get().strip(),'en':self.l_en.get().strip()},previous_level_id=self.l_prev.get().strip() or None)
    def create_level(self):
        try:p=self._level_payload();p['id']=self.l_id.get().strip()
        except ValueError:return messagebox.showerror('Invalid','Position must be numeric',parent=self)
        self._job('Creating draft level',lambda:self.client.post('/levels',p),lambda _:self.refresh_levels())
    def save_level(self):
        if not self.selected_level:return messagebox.showerror('Select','Select level first',parent=self)
        try:p=self._level_payload();p.pop('world_id');p.pop('display_code')
        except ValueError:return messagebox.showerror('Invalid','Position must be numeric',parent=self)
        self._job('Saving level metadata',lambda:self.client.patch('/levels/'+self.selected_level['id'],p),lambda _:self.refresh_levels())
    def unpublish_level(self):
        if self.selected_level and self._confirm('Hide this level for new gameplay? Existing runs remain pinned to their revision.'):
            self._job('Unpublishing level',lambda:self.client.post('/levels/'+self.selected_level['id']+'/unpublish'),lambda _:self.refresh_levels())

    def _revisions_tab(self):
        p=ttk.Frame(self.tabs);self.tabs.add(p,text='Puzzle ZIP / Revisions')
        self.rev_cols=('id','level_id','revision','state');self.rev_tree=self._tree(p,self.rev_cols)
        self.rev_tree.bind('<<TreeviewSelect>>',self._select_revision)
        f=ttk.Frame(p);f.pack(fill='x',padx=12,pady=10)
        self.zip_path=tk.StringVar();self.revision_id=tk.StringVar();self.device_qa=tk.BooleanVar()
        self._line(f,'Local puzzle ZIP',self.zip_path,80).pack(fill='x')
        self.fix_world_id=tk.StringVar()
        chooser=ttk.Frame(f);chooser.pack(fill='x',pady=3)
        ttk.Label(chooser,text='Server World ID').pack(side='left',padx=(0,8))
        self.fix_world_combo=ttk.Combobox(chooser,textvariable=self.fix_world_id,width=26,state='readonly')
        self.fix_world_combo.pack(side='left',padx=(0,8))
        ttk.Button(chooser,text='Repair ZIP World ID (new UUID)',command=self.repair_zip_world).pack(side='left')
        ttk.Button(f,text='Browse ZIP',command=self._zip_choose).pack(anchor='w',pady=6)
        ttk.Button(f,text='Verify + Import ZIP to Server',command=self.import_zip).pack(anchor='w',pady=6)
        self._line(f,'Revision UUID',self.revision_id,50).pack(fill='x')
        ttk.Checkbutton(f,text='Device QA completed on required hardware (explicit approval)',variable=self.device_qa).pack(anchor='w',pady=6)
        row=ttk.Frame(f);row.pack(fill='x')
        self._action(row,'Refresh Revisions',self.refresh_revisions)
        self._action(row,'Publish Selected Revision',self.publish_revision)
    def _zip_choose(self):
        path=filedialog.askopenfilename(parent=self,filetypes=[('PuzzleQuest ZIP','*.zip')]);
        if path:self.zip_path.set(path)
    def refresh_revisions(self):
        if not self.client:return messagebox.showerror('Disconnected','Connect to the dashboard first.',parent=self)
        self._job('Fetching revisions',self.client.revisions,self._revision_result)
    def _revision_result(self,rows):self.rev_rows=rows;self._refresh_tree(self.rev_tree,rows,self.rev_cols)
    def _select_revision(self,*_):
        sel=self.rev_tree.selection()
        if sel:self.revision_id.set(self.rev_rows[int(sel[0])]['id'])
    def repair_zip_world(self):
        from .laravel_import import repair_laravel_world
        src=Path(self.zip_path.get())
        target_world=self.fix_world_id.get()
        if not src.is_file():return messagebox.showerror('ZIP required','Select an exported ZIP first.',parent=self)
        if target_world not in [r['id'] for r in self.world_rows]:
            return messagebox.showerror('Invalid World','Pick a World ID returned by the server.',parent=self)
        if not self._confirm(f'Create a NEW ZIP targeting server world {target_world}? Original ZIP will remain unchanged.'):
            return
        # CPU-intensive quality verification happens off the GUI thread.
        def do_repair():
            new_zip=repair_laravel_world(src,target_world)
            return str(new_zip)
        self._job('Creating verified corrected ZIP',do_repair,self._zip_repaired)

    def _zip_repaired(self,path):
        self.zip_path.set(path)
        messagebox.showinfo('New ZIP ready','Saved corrected package with new Revision UUID:\n'+path+'\n\nNow use Verify + Import ZIP.',parent=self)

    def import_zip(self):
        path=Path(self.zip_path.get());
        if not path.is_file():return messagebox.showerror('File required','Choose the exported ZIP',parent=self)
        if self._confirm('Quality Gate + server World ID preflight, then upload this ZIP as a NEW draft?'):
            self._job('Validating ZIP and World ID before uploading',lambda:self._verify_and_import(path),self._import_result)

    def _verify_and_import(self,path):
        from .laravel_import import verify_laravel_archive
        report=verify_laravel_archive(path)
        if not report.passed:
            problems=[c['name']+': '+c['detail'] for c in report.checks if not c['passed']]
            raise StudioApiError('Local Quality Gate blocked the ZIP: '+'; '.join(problems[:5]))
        return self.client.import_zip(path)
    def _import_result(self,r):
        self.revision_id.set(r['id']);messagebox.showinfo('Imported',f'Draft revision: {r["id"]}\nServer state: {r["state"]}',parent=self);self.refresh_revisions()
    def publish_revision(self):
        if not self.device_qa.get():return messagebox.showerror('QA required','Explicit device QA is required before publication.',parent=self)
        rid=self.revision_id.get().strip()
        if not rid:return messagebox.showerror('Revision required','Select revision from list.',parent=self)
        if self._confirm('Publish this revision to players? This is a LIVE operation.'):
            self._job('Publishing server revision',lambda:self.client.post('/revisions/'+rid+'/publish',{'device_qa_approved':True}),lambda _:self.refresh_revisions())

    def _documents_tab(self):
        p=ttk.Frame(self.tabs);self.tabs.add(p,text='Collections • Events • Village • More')
        top=ttk.Frame(p);top.pack(fill='x',padx=8,pady=6)
        self.kind=tk.StringVar(value='village_scene');ttk.Label(top,text='Content Category').pack(side='left');ttk.Combobox(top,textvariable=self.kind,values=KINDS,width=22,state='readonly').pack(side='left',padx=8)
        self._action(top,'Reload Category',self.refresh_documents)
        self.doc_cols=('id','slug','world_id','position','state','draft_revision','live_revision')
        self.doc_tree=self._tree(p,self.doc_cols)
        self.doc_tree.configure(height=8);self.doc_tree.bind('<<TreeviewSelect>>',self._select_doc)
        f=ttk.Frame(p);f.pack(fill='x',padx=10)
        self.d_slug=tk.StringVar();self.d_world=tk.StringVar();self.d_pos=tk.StringVar(value='1');self.d_ar=tk.StringVar();self.d_en=tk.StringVar()
        for label,var in [('Slug',self.d_slug),('World ID (optional)',self.d_world),('Position',self.d_pos),('Title AR',self.d_ar),('Title EN',self.d_en)]:self._line(f,label,var,80).pack(fill='x',pady=2)
        ttk.Label(f,text='Draft JSON payload: collection members, event schedule, village objects, artwork references').pack(anchor='w',pady=(4,0))
        self.payload=tk.Text(f,height=8,undo=True,wrap='word',bg='#1d2938',fg='white',insertbackground='white')
        self.payload.pack(fill='both',expand=True,pady=5);self.payload.insert('1.0','{"background_asset_id":null,"objects":[]}')
        row=ttk.Frame(f);row.pack(fill='x')
        for label,fn in [('New Template',self.new_doc),('Create Draft',self.create_doc),('Save Draft',self.save_doc),('Publish',self.publish_doc),('Retire',self.retire_doc),('Village Visual Editor',self.village_editor),('History / Restore Draft',self.restore_doc)]:self._action(row,label,fn)
        self.kind.trace_add('write',lambda *_:self.refresh_documents() if self.client and not self.busy else None)
    def refresh_documents(self):
        if not self.client:return messagebox.showerror('Disconnected','Connect to the dashboard first.',parent=self)
        kind=self.kind.get();self._job('Fetching '+kind,lambda:self.client.documents(kind),self._documents_result)
    def _documents_result(self,rows):self.doc_rows=rows;self._refresh_tree(self.doc_tree,rows,self.doc_cols);self.selected_doc=None
    def _select_doc(self,*_):
        sel=self.doc_tree.selection()
        if not sel:return
        self.selected_doc=self.doc_rows[int(sel[0])];d=self.selected_doc
        for var,k in [(self.d_slug,'slug'),(self.d_world,'world_id'),(self.d_pos,'position')]:var.set(str(d.get(k)or''))
        self.d_ar.set(d['title']['ar']);self.d_en.set(d['title']['en']);self._set_payload(d['draft_payload'])
    def _set_payload(self,payload):self.payload.delete('1.0','end');self.payload.insert('1.0',json.dumps(payload,indent=2,ensure_ascii=False))
    def new_doc(self):
        self.selected_doc=None;self.d_slug.set('');self.d_ar.set('');self.d_en.set('');self.d_pos.set('1')
        kind=self.kind.get()
        if kind=='village_scene':data={'background_asset_id':None,'objects':[]}
        elif kind=='village_item':data={'image_asset_id':'PASTE-UPLOADED-ASSET-UUID','building_id':'cottage','stage':0}
        elif kind=='event':
            start=datetime.now(timezone.utc)+timedelta(days=1);end=start+timedelta(days=7)
            data={'starts_at':start.strftime('%Y-%m-%dT%H:%M:%SZ'),'ends_at':end.strftime('%Y-%m-%dT%H:%M:%SZ'),'description':{'ar':'','en':''},'level_ids':[]}
        elif kind=='collection':data={'level_ids':[],'description':{'ar':'','en':''}}
        elif kind=='level_group':data={'level_ids':[]}
        else:data={}
        self._set_payload(data)
    def _doc_payload(self):return dict(world_id=self.d_world.get().strip() or None,title={'ar':self.d_ar.get().strip(),'en':self.d_en.get().strip()},position=int(self.d_pos.get()),payload=self._json(self.payload))
    def create_doc(self):
        try:d=self._doc_payload();d.update(kind=self.kind.get(),slug=self.d_slug.get().strip())
        except Exception as e:return messagebox.showerror('Invalid draft',str(e),parent=self)
        self._job('Creating document draft',lambda:self.client.post('/documents',d),lambda _:self.refresh_documents())
    def save_doc(self):
        if not self.selected_doc:return messagebox.showerror('Select document','Select a saved draft first, or Create Draft.',parent=self)
        try:d=self._doc_payload();d['draft_revision']=self.selected_doc['draft_revision']
        except Exception as e:return messagebox.showerror('Invalid draft',str(e),parent=self)
        self._job('Saving draft without altering published revision',lambda:self.client.patch('/documents/'+self.selected_doc['id'],d),lambda _:self.refresh_documents())
    def publish_doc(self):
        if not self.selected_doc:return messagebox.showerror('Select','Select a document',parent=self)
        if not self._confirm('Content QA finished? Publish this draft snapshot to the public API?'):return
        d=self.selected_doc
        self._job('Publishing immutable snapshot',lambda:self.client.post('/documents/'+d['id']+'/publish',{'draft_revision':d['draft_revision'],'content_qa_approved':True}),lambda _:self.refresh_documents())
    def retire_doc(self):
        if self.selected_doc and self._confirm('Retire this item from public catalog (historical revisions preserved)?'):
            self._job('Retiring content',lambda:self.client.post('/documents/'+self.selected_doc['id']+'/retire'),lambda _:self.refresh_documents())
    def restore_doc(self):
        if not self.selected_doc:return messagebox.showerror('Select','Select a published document.',parent=self)
        d=self.selected_doc
        self._job('Loading published revision history',lambda:self.client.get('/documents/'+d['id']+'/history')['items'],lambda rows:self._prompt_restore(d,rows))
    def _prompt_restore(self,d,rows):
        if not rows:return messagebox.showinfo('History','No published revisions yet.',parent=self)
        win=tk.Toplevel(self);win.title('Restore a published revision into a NEW draft');win.geometry('500x300')
        ttk.Label(win,text='Select revision. Existing live content is unchanged until explicit publish.').pack(pady=8)
        box=ttk.Combobox(win,values=[str(r['revision']) for r in rows],state='readonly')
        box.pack(fill='x',padx=20,pady=10);box.current(0)
        def restore():
            rev=box.get();win.destroy()
            if not self._confirm('Restore snapshot '+rev+' to draft only?') :return
            self._job('Restoring previous snapshot to draft',lambda:self.client.post('/documents/'+d['id']+'/restore/'+rev,{'draft_revision':d['draft_revision']}),lambda _:self.refresh_documents())
        ttk.Button(win,text='Restore into Draft',command=restore).pack(pady=12)

    def village_editor(self):
        if self.kind.get()!='village_scene':return messagebox.showerror('Category','Select village_scene first',parent=self)
        try:payload=self._json(self.payload)
        except Exception as e:return messagebox.showerror('Invalid JSON',str(e),parent=self)
        if not self.media_rows:return messagebox.showerror('No images','Upload images in the Media tab first.',parent=self)
        from .village_editor import VillageLayoutEditor
        VillageLayoutEditor(self,payload,self.media_rows,self.client.origin,self._set_payload)

    def _media_tab(self):
        p=ttk.Frame(self.tabs);self.tabs.add(p,text='Image Asset Library')
        self.media_cols=('id','width','height','mime','bytes');self.media_tree=self._tree(p,self.media_cols)
        f=ttk.Frame(p);f.pack(fill='x',padx=12,pady=15)
        ttk.Label(f,text='PNG / JPG / WebP • max 8 MB and 12 megapixels • stored as immutable assets').pack(anchor='w')
        self.asset_path=tk.StringVar();self._line(f,'Image file',self.asset_path,80).pack(fill='x',pady=5)
        row=ttk.Frame(f);row.pack(fill='x')
        self._action(row,'Browse Image',self.choose_media)
        self._action(row,'Upload Image',self.upload_media)
        self._action(row,'Refresh Media',self.refresh_media)
        self._action(row,'Copy Selected Asset UUID',self.copy_media)
    def choose_media(self):
        p=filedialog.askopenfilename(parent=self,filetypes=[('Images','*.png *.jpg *.jpeg *.webp')]);
        if p:self.asset_path.set(p)
    def refresh_media(self):
        if not self.client:return messagebox.showerror('Disconnected','Connect to the dashboard first.',parent=self)
        self._job('Fetching uploaded artwork',self.client.media,self._media_result)
    def _media_result(self,rows):self.media_rows=rows;self._refresh_tree(self.media_tree,rows,self.media_cols)
    def upload_media(self):
        path=Path(self.asset_path.get())
        if not path.is_file():return messagebox.showerror('File','Select a local image.',parent=self)
        self._job('Uploading artwork',lambda:self.client.upload_image(path),lambda _:self.refresh_media())
    def copy_media(self):
        sel=self.media_tree.selection()
        if not sel:return
        asset=self.media_rows[int(sel[0])]
        self.clipboard_clear();self.clipboard_append(asset['id']);self.status.set('Asset UUID copied; paste it in the document JSON.')
