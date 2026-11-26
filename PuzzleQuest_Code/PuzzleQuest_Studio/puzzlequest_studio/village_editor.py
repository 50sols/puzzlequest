"""Coordinate-based village artwork editor; outputs deterministic normalized placements."""
from __future__ import annotations
import io
import tkinter as tk
from tkinter import ttk, messagebox
from urllib.parse import urlsplit
from urllib.request import urlopen
from PIL import Image, ImageTk


class VillageLayoutEditor(tk.Toplevel):
    CW,CH=720,470
    def __init__(self, parent, payload, assets, origin, on_save):
        super().__init__(parent)
        self.title('PuzzleQuest • Village Visual Placement')
        self.geometry('1080x670')
        self.configure(bg='#111827')
        self.payload=dict(payload)
        self.payload.setdefault('background_asset_id',None)
        self.payload.setdefault('objects',[])
        self.objects=[dict(o) for o in self.payload['objects']]
        self.assets={a['id']:a for a in assets}
        self.origin=origin
        self.on_save=on_save
        self.cache={}
        self.selection=None
        self.dragging=None
        self.asset=tk.StringVar(value=next(iter(self.assets),'') )
        self.scale=tk.StringVar(value='1.0')
        self.stage=tk.StringVar(value='0')
        self.building=tk.StringVar(value='')
        left=tk.Frame(self,bg='#111827');left.pack(side='left',padx=16,pady=14)
        self.canvas=tk.Canvas(left,width=self.CW,height=self.CH,bg='#477a52',highlightthickness=1,highlightbackground='#55737b')
        self.canvas.pack()
        self.canvas.bind('<Button-1>',self._press)
        self.canvas.bind('<B1-Motion>',self._drag)
        self.canvas.bind('<ButtonRelease-1>',lambda e:self._release())
        tk.Label(left,text='Drag objects to arrange. Coordinates use 0..1 and scale with screen size.',fg='#d1d5db',bg='#111827').pack()
        right=tk.Frame(self,bg='#111827');right.pack(side='left',fill='both',expand=True,padx=12,pady=15)
        def label(t):tk.Label(right,text=t,fg='white',bg='#111827').pack(anchor='w')
        label('Asset (uploaded artwork)')
        ttk.Combobox(right,textvariable=self.asset,values=list(self.assets),width=38).pack(fill='x',pady=5)
        ttk.Button(right,text='Use as Background',command=self._background).pack(fill='x',pady=4)
        ttk.Button(right,text='Add Item at Center',command=self._add).pack(fill='x',pady=4)
        label('Building id (cottage / windmill etc.)')
        ttk.Entry(right,textvariable=self.building).pack(fill='x',pady=5)
        label('Building stage: 0–4')
        ttk.Combobox(right,textvariable=self.stage,values=['0','1','2','3','4']).pack(fill='x',pady=5)
        label('Scale: 0.1–4')
        ttk.Entry(right,textvariable=self.scale).pack(fill='x',pady=5)
        self.items=tk.Listbox(right,height=10);self.items.pack(fill='both',expand=True,pady=8)
        self.items.bind('<<ListboxSelect>>',self._selected)
        ttk.Button(right,text='Apply Scale / Stage / Building',command=self._modify).pack(fill='x',pady=2)
        ttk.Button(right,text='Remove Selected Item',command=self._remove).pack(fill='x',pady=2)
        ttk.Button(right,text='Send Layout to Draft Editor',command=self._save).pack(fill='x',pady=12)
        self._draw()

    def _img(self,asset_id,maxsize):
        if not asset_id or asset_id not in self.assets:return None
        key=(asset_id,maxsize)
        if key in self.cache:return self.cache[key]
        u=urlsplit(self.assets[asset_id]['url'])
        if u.scheme!='https' or f'{u.scheme}://{u.netloc}'!=self.origin:return None
        try:
            with urlopen(self.assets[asset_id]['url'],timeout=6) as r:data=r.read(8*1024*1024)
            image=Image.open(io.BytesIO(data)).convert('RGBA');image.thumbnail(maxsize,Image.Resampling.LANCZOS)
            photo=ImageTk.PhotoImage(image)
            self.cache[key]=photo
            return photo
        except Exception:return None

    def _draw(self):
        self.canvas.delete('all');self.visible={}
        bg=self._img(self.payload.get('background_asset_id'),(self.CW,self.CH))
        if bg:self.canvas.create_image(self.CW//2,self.CH//2,image=bg,anchor='center')
        else:self.canvas.create_text(self.CW//2,25,text='Village background: select and press Use as Background',fill='white')
        for i,obj in sorted(enumerate(self.objects),key=lambda z:z[1].get('z',0)):
            x=int(float(obj.get('x',.5))*self.CW);y=int(float(obj.get('y',.5))*self.CH)
            sz=max(30,min(160,int(80*float(obj.get('scale',1)))))
            pic=self._img(obj['asset_id'],(sz,sz))
            if pic:self.canvas.create_image(x,y,image=pic,anchor='center',tags=(f'obj:{i}',))
            else:self.canvas.create_rectangle(x-sz//2,y-sz//2,x+sz//2,y+sz//2,fill='#e3ab57',outline='#38d9bd' if i==self.selection else '#303030',width=3,tags=(f'obj:{i}',))
            self.canvas.create_text(x,y+sz//2+8,text=str(i+1),fill='white',tags=(f'obj:{i}',))
            self.visible[i]=(x,y)
        self.items.delete(0,'end')
        for i,obj in enumerate(self.objects):self.items.insert('end',f'{i+1}: {obj.get("building_id", "art")} L{obj.get("stage",0)}  ({obj["x"]:.2f},{obj["y"]:.2f})')
        if self.selection is not None and self.selection<len(self.objects):self.items.selection_set(self.selection)

    def _background(self):
        if self.asset.get() not in self.assets:return messagebox.showerror('Invalid asset','Upload/select an image first',parent=self)
        self.payload['background_asset_id']=self.asset.get();self._draw()
    def _add(self):
        if self.asset.get() not in self.assets:return messagebox.showerror('Invalid asset','Choose an uploaded asset',parent=self)
        try:scale=float(self.scale.get());stage=int(self.stage.get());assert .1<=scale<=4 and 0<=stage<=4
        except Exception:return messagebox.showerror('Invalid values','Scale must be 0.1–4 and stage 0–4',parent=self)
        obj={'id':f'item_{len(self.objects)+1}','asset_id':self.asset.get(),'x':.5,'y':.5,'scale':scale,'z':len(self.objects),'building_id':self.building.get().strip(),'stage':stage}
        self.objects.append(obj);self.selection=len(self.objects)-1;self._draw()
    def _selected(self,e=None):
        if not self.items.curselection():return
        self.selection=self.items.curselection()[0];o=self.objects[self.selection]
        self.asset.set(o['asset_id']);self.scale.set(str(o.get('scale',1)));self.stage.set(str(o.get('stage',0)));self.building.set(o.get('building_id',''))
    def _press(self,e):
        hits=self.canvas.find_overlapping(e.x-10,e.y-10,e.x+10,e.y+10)
        for hit in reversed(hits):
            for tag in self.canvas.gettags(hit):
                if tag.startswith('obj:'):
                    self.selection=int(tag.split(':',1)[1]);self.dragging=self.selection;self.items.selection_clear(0,'end');self.items.selection_set(self.selection);return
    def _drag(self,e):
        if self.dragging is None:return
        o=self.objects[self.dragging];o['x']=round(max(0,min(1,e.x/self.CW)),5);o['y']=round(max(0,min(1,e.y/self.CH)),5);self._draw()
    def _release(self):self.dragging=None
    def _modify(self):
        if self.selection is None:return
        try:scale=float(self.scale.get());stage=int(self.stage.get());assert .1<=scale<=4 and 0<=stage<=4
        except Exception:return messagebox.showerror('Invalid values','Scale 0.1–4; stage 0–4',parent=self)
        self.objects[self.selection].update(scale=scale,stage=stage,building_id=self.building.get().strip());self._draw()
    def _remove(self):
        if self.selection is None:return
        del self.objects[self.selection];self.selection=None;self._draw()
    def _save(self):
        self.payload['objects']=self.objects
        self.on_save(self.payload);self.destroy()
