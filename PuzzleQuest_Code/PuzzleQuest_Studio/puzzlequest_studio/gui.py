"""Dark desktop GUI using built-in Tkinter; no local server or cloud account."""
from __future__ import annotations

from datetime import datetime
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from PIL import Image, ImageOps, ImageTk

from .builder import BuildConfig, build_package
from .quality import validate_archive
from .laravel_import import build_laravel_package, verify_laravel_archive

BG = "#0B1020"
PANEL = "#161F35"
CARD = "#1C2941"
FG = "#F2F6FF"
MUTED = "#A8B6D3"
ACCENT = "#27C697"
ENTRY = "#26334E"


class Studio(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("PuzzleQuest Studio • v1.1.2 (Offline + Online)")
        self.geometry("1180x940")
        self.minsize(1040, 800)
        self.configure(bg=BG)
        self.selected_image = tk.StringVar()
        self.dest = tk.StringVar(value=str(Path.home() / "PuzzleQuest-Exports"))
        self.pieces = tk.StringVar(value="36")
        self.world = tk.StringVar(value="green_valley")
        self.level = tk.StringVar(value="1-6")
        self.display_code = tk.StringVar(value="")  # Empty means use Level ID.
        self.position = tk.StringVar(value="")  # Empty means infer from level ID, e.g. 1-6 => 6.
        self.title_value = tk.StringVar(value="Green Valley Watermill")
        self.title_ar_value = tk.StringVar(value="طاحونة الوادي الأخضر")
        self.backend_level = tk.StringVar(value="")
        self.previous_backend_level = tk.StringVar(value="")
        self.fit = tk.StringVar(value="crop")
        self.resolution = tk.StringVar(value="960")
        self.total = tk.StringVar(value="600")
        self.three = tk.StringVar(value="210")
        self.two = tk.StringVar(value="420")
        self.prereq = tk.StringVar(value="1-5")
        self.rights = tk.BooleanVar(value=False)
        self.status = tk.StringVar(value="Ready. Choose an image to begin.")
        self.progress = tk.IntVar(value=0)
        self.messages: queue.Queue[tuple] = queue.Queue()
        self.working = False
        self.preview_ref = None
        self.last_export: Path | None = None
        self._make_ui()
        self.after(120, self._poll)

    def _label(self, parent, text, size=11, color=FG, bold=False, **kwargs):
        return tk.Label(parent, text=text, bg=parent.cget("bg"), fg=color,
                        font=("Segoe UI", size, "bold" if bold else "normal"), **kwargs)

    def _field(self, parent, heading, variable, width=22):
        block = tk.Frame(parent, bg=PANEL)
        self._label(block, heading, color=MUTED, size=10).pack(anchor="w", pady=(0,4))
        entry = tk.Entry(block, textvariable=variable, bg=ENTRY, fg=FG, insertbackground=FG,
                         relief="flat", font=("Segoe UI", 11), width=width,
                         highlightthickness=1, highlightbackground="#354765")
        entry.pack(fill="x", ipady=9)
        return block

    def _button(self, parent, text, command, primary=True):
        return tk.Button(parent, text=text, command=command, bg=ACCENT if primary else ENTRY,
                         fg="#092018" if primary else FG, activebackground="#54E8BD",
                         activeforeground="#092018", relief="flat", bd=0, font=("Segoe UI",11,"bold"),
                         cursor="hand2", pady=11)

    def _option(self, parent, heading, variable, options):
        block = tk.Frame(parent, bg=PANEL)
        self._label(block, heading, size=10, color=MUTED).pack(anchor="w", pady=(0,4))
        selector = tk.OptionMenu(block, variable, *options)
        selector.configure(bg=ENTRY, fg=FG, activebackground="#344A68", activeforeground=FG,
                           highlightthickness=0, relief="flat", font=("Segoe UI", 10), width=12)
        selector["menu"].configure(bg=ENTRY, fg=FG, activebackground=ACCENT)
        selector.pack(fill="x")
        return block

    def _make_ui(self):
        header = tk.Frame(self, bg=BG)
        header.pack(fill="x", padx=24, pady=(22,14))
        self._label(header, "🧩  PuzzleQuest Studio", 22, FG, True).pack(anchor="w")
        self._button(header, "☁  Open Online Manager • Worlds / Levels / Village / Events / Collections", self.open_online_manager, False).pack(fill="x",pady=(8,4))
        self._label(header, "OFFLINE JIGSAW PACKAGE GENERATOR  •  IMMUTABLE UUID REVISION  •  QUALITY GATE",
                    size=10, color=MUTED).pack(anchor="w", pady=(3,0))

        body = tk.Frame(self, bg=BG)
        body.pack(fill="both", expand=True, padx=24)
        left = tk.Frame(body, bg=PANEL, padx=20, pady=18)
        left.pack(side="left", fill="both", expand=True, padx=(0,10))
        right = tk.Frame(body, bg=PANEL, padx=18, pady=18, width=330)
        right.pack(side="right", fill="both", padx=(10,0))
        right.pack_propagate(False)

        self._label(left, "01   IMAGE & LEVEL", 12, FG, True).pack(anchor="w", pady=(0,10))
        self._button(left, "Select source image (PNG / JPG / WebP)", self.choose_image, False).pack(fill="x")
        self.image_name = self._label(left, "No image selected", 10, MUTED)
        self.image_name.pack(anchor="w", pady=(7,13))
        row = tk.Frame(left, bg=PANEL)
        row.pack(fill="x", pady=4)
        for heading, variable in (("World ID (copy from Admin > Worlds)",self.world),("Display Code (e.g. 1-6)",self.level)):
            self._field(row,heading,variable).pack(side="left", expand=True, fill="x", padx=(0,8))
        self._label(left, "World ID must match an existing worlds.id in the dashboard DB", size=9, color="#FFCE83").pack(anchor="w", pady=(2,4))
        row_code = tk.Frame(left, bg=PANEL)
        row_code.pack(fill="x", pady=(3,7))
        self._field(row_code,"English Title",self.title_value).pack(side="left",expand=True,fill="x",padx=(0,8))
        self._field(row_code,"Arabic Title",self.title_ar_value).pack(side="left",expand=True,fill="x",padx=(0,8))
        self._field(row_code,"Position (auto)",self.position,width=8).pack(side="left",fill="x")
        identifiers=tk.Frame(left,bg=PANEL)
        identifiers.pack(fill="x",pady=(0,9))
        self._field(identifiers,"Server level_id (auto, optional)",self.backend_level).pack(side="left",expand=True,fill="x",padx=(0,8))
        self._field(identifiers,"Previous server level_id (optional)",self.previous_backend_level).pack(side="left",expand=True,fill="x")
        row2 = tk.Frame(left, bg=PANEL)
        row2.pack(fill="x", pady=(0,10))
        for heading, var, options in (("Number of pieces",self.pieces,["16","36","64","100"]),
                                       ("Board 960px",self.resolution,["960"]),
                                       ("Image framing",self.fit,["crop","contain"])):
            self._option(row2,heading,var,options).pack(side="left",fill="x",expand=True,padx=(0,8))
        self._label(left, "02   TIMERS & UNLOCK", 12, FG, True).pack(anchor="w", pady=(8,11))
        timers = tk.Frame(left,bg=PANEL)
        timers.pack(fill="x")
        for name,var in (("Total seconds",self.total),("3 stars ≤ sec",self.three),("2 stars ≤ sec",self.two)):
            self._field(timers,name,var,width=11).pack(side="left",expand=True,fill="x",padx=(0,8))
        self._label(left,"Previous level ID for Laravel is a DB identifier, not 1-5; optional field above.",size=9,color=MUTED).pack(anchor="w",pady=(9,5))
        checkbox = tk.Checkbutton(left, text="I confirm the right to use and publish this image",
                                  variable=self.rights, onvalue=True, offvalue=False,
                                  bg=PANEL, fg=FG, activebackground=PANEL, activeforeground=FG,
                                  selectcolor=ENTRY, font=("Segoe UI", 10))
        checkbox.pack(anchor="w", pady=(9,11))
        self._label(left,"03   EXPORT DESTINATION",12,FG,True).pack(anchor="w",pady=(1,9))
        dest_row = tk.Frame(left,bg=PANEL)
        dest_row.pack(fill="x")
        self._field(dest_row,"Folder for validated ZIP packages",self.dest).pack(side="left",fill="x",expand=True,padx=(0,6))
        self._button(dest_row,"Browse",self.choose_output,False).pack(side="right",anchor="s",pady=(22,0))
        self.build_button = self._button(left,"GENERATE & VERIFY ZIP  →",self.generate)
        self.build_button.pack(fill="x",pady=(17,6))
        self._button(left,"Verify an existing ZIP",self.verify_existing,False).pack(fill="x")

        self._label(right,"SOURCE PREVIEW",12,FG,True).pack(anchor="w",pady=(0,10))
        preview_frame = tk.Frame(right,bg=CARD,height=282)
        preview_frame.pack(fill="x")
        preview_frame.pack_propagate(False)
        self.preview = tk.Label(preview_frame,text="Choose an image to preview",fg=MUTED,bg=CARD,
                                font=("Segoe UI",11))
        self.preview.pack(expand=True)
        self._label(right,"OUTPUT QUALITY GATE",12,FG,True).pack(anchor="w",pady=(21,10))
        for text in ("✓ 9 server-required metadata fields", "✓ Laravel manifest 960x960 schema",
                     "✓ master.png + N_pieces + N_masks_svg", "✓ row_major piece_000 IDs, anchors & edges",
                     "✓ Full image pixel coverage", "✓ UUIDv4 revision & safe ZIP",
                     "✓ Re-open ZIP with contract verifier"):
            self._label(right,text,10,MUTED).pack(anchor="w",pady=3)
        self._label(right,"FAIL CLOSED: any failed check blocks export",10,"#FFABAE",True).pack(anchor="w",pady=(13,0))

        foot = tk.Frame(self,bg=BG)
        foot.pack(fill="x",padx=24,pady=(15,19))
        ttk.Style(self).configure("PQ.Horizontal.TProgressbar", troughcolor=ENTRY,
                                  background=ACCENT, thickness=12)
        ttk.Progressbar(foot,orient="horizontal",mode="determinate",variable=self.progress,
                        maximum=100,style="PQ.Horizontal.TProgressbar").pack(fill="x",pady=(0,10))
        self._label(foot,"ACTIVITY",10,MUTED,True).pack(anchor="w")
        self.activity = tk.Text(foot,height=3,wrap="word",bg=PANEL,fg=MUTED,font=("Consolas",10),
                                relief="flat",padx=12,pady=8)
        self.activity.pack(fill="x")
        self.activity.insert("end","Ready.\n")
        self.activity.configure(state="disabled")
        self.pieces.trace_add("write",self._suggest_timer)
        self.level.trace_add("write",self._suggest_locked_level)

    def open_online_manager(self):
        from .online_manager import OnlineManager
        OnlineManager(self)

    def _suggest_locked_level(self,*_):
        launch = {"1-1": (16, 360, 150, 270, None),
                  "1-2": (16, 360, 150, 270, "1-1"),
                  "1-3": (36, 600, 270, 450, "1-2"),
                  "1-4": (64, 1080, 480, 840, "1-3"),
                  "1-5": (100, 1800, 900, 1440, "1-4")}
        if self.world.get() == "green-valley" and self.level.get() in launch:
            pieces, total, three, two, prerequisite = launch[self.level.get()]
            self.pieces.set(str(pieces))
            self.total.set(str(total)); self.three.set(str(three)); self.two.set(str(two))
            self.prereq.set(prerequisite or "")

    def _suggest_timer(self,*_):
        defaults = {"16":(240,90,175),"36":(600,210,420),"64":(900,330,650),"100":(1500,600,1120)}
        if self.pieces.get() in defaults:
            total,three,two = defaults[self.pieces.get()]
            self.total.set(str(total));self.three.set(str(three));self.two.set(str(two))

    def _log(self,message):
        self.activity.configure(state="normal")
        self.activity.insert("end",f"{datetime.now():%H:%M:%S}  {message}\n")
        self.activity.see("end")
        self.activity.configure(state="disabled")

    def choose_image(self):
        path=filedialog.askopenfilename(title="Choose artwork",filetypes=[("Images","*.png *.jpg *.jpeg *.webp"),("All files","*.*")])
        if path:
            self.selected_image.set(path)
            self.image_name.configure(text=Path(path).name)
            self._show_preview(Path(path))
            self._log("Selected: " + Path(path).name)

    def _show_preview(self,path):
        try:
            with Image.open(path) as im:
                image=ImageOps.exif_transpose(im).convert("RGB")
                image.thumbnail((280,270))
                self.preview_ref=ImageTk.PhotoImage(image)
                self.preview.configure(image=self.preview_ref,text="")
        except Exception as exc:
            self.preview.configure(text=f"Preview unavailable: {exc}",image="")

    def choose_output(self):
        path=filedialog.askdirectory(title="Select output folder",initialdir=self.dest.get())
        if path:self.dest.set(path)

    def _set_busy(self,busy:bool):
        self.working=busy
        self.build_button.configure(state="disabled" if busy else "normal")

    def generate(self):
        if self.working:return
        try:
            cfg=BuildConfig(
                image_path=Path(self.selected_image.get()),output_dir=Path(self.dest.get()),
                piece_count=int(self.pieces.get()),world_id=self.world.get().strip(),
                level_id=self.level.get().strip(),display_code=self.display_code.get().strip() or None,
                position=int(self.position.get().strip()) if self.position.get().strip() else None,
                title=self.title_value.get(),
                resolution=int(self.resolution.get()),image_mode=self.fit.get(),
                total_seconds=int(self.total.get()),three_star_seconds=int(self.three.get()),
                two_star_seconds=int(self.two.get()),
                prerequisite_level_id=None,
                approved_rights=self.rights.get())
            cfg.validate()
        except (ValueError,TypeError,OSError) as exc:
            messagebox.showerror("Invalid input",str(exc));return
        self._set_busy(True)
        self.progress.set(0)
        self._log("Starting package generation")
        options={"backend_level_id":self.backend_level.get().strip() or None,
                 "title_ar":self.title_ar_value.get().strip(),
                 "title_en":self.title_value.get().strip(),
                 "previous_level_id":self.previous_backend_level.get().strip() or None}
        threading.Thread(target=self._build, args=(cfg,options), daemon=True).start()

    def _build(self,cfg,options):
        try:
            output=build_laravel_package(cfg,progress=lambda pct,detail:self.messages.put(("progress",pct,detail)),**options)
            self.messages.put(("done",output))
        except Exception as exc:
            self.messages.put(("error",str(exc)))

    def verify_existing(self):
        if self.working:return
        path=filedialog.askopenfilename(title="Verify a PuzzleQuest package",filetypes=[("ZIP packages","*.zip")])
        if not path:return
        self._set_busy(True)
        self._log("Auditing existing ZIP: "+Path(path).name)
        threading.Thread(target=self._verify,args=(path,),daemon=True).start()

    def _verify(self,path):
        try:
            with __import__('zipfile').ZipFile(path) as z:
                dashboard=isinstance(__import__('json').loads(z.read('manifest.json')),dict) and                     __import__('json').loads(z.read('manifest.json')).get('board_size_px') == [960,960]
            report=verify_laravel_archive(path) if dashboard else validate_archive(path)
            self.messages.put(("verify",report,Path(path)))
        except Exception as exc:
            self.messages.put(("error","Cannot verify ZIP: "+str(exc)))

    def _poll(self):
        try:
            while True:
                event=self.messages.get_nowait()
                if event[0]=="progress":
                    self.progress.set(event[1]);self.status.set(event[2]);self._log(event[2])
                elif event[0]=="done":
                    self.last_export=event[1]
                    self._set_busy(False)
                    self._log("PASS — exported: "+str(event[1]))
                    messagebox.showinfo("Quality Gate PASSED","Verified ZIP created:\n"+str(event[1]))
                    try:
                        with __import__("zipfile").ZipFile(event[1]) as z:
                            from io import BytesIO
                            image_name="master.png" if "master.png" in z.namelist() else "images/board-preview.webp"
                            with Image.open(BytesIO(z.read(image_name))) as im:
                                im.thumbnail((280,270));self.preview_ref=ImageTk.PhotoImage(im.copy())
                                self.preview.configure(image=self.preview_ref,text="")
                    except Exception:
                        pass
                elif event[0]=="verify":
                    self._set_busy(False)
                    report, path=event[1],event[2]
                    failed=[c["name"] for c in report.checks if not c["passed"]]
                    self._log(("PASS" if report.passed else "FAIL")+f" — {len(report.checks)} archive audit checks")
                    for err in failed:self._log("FAIL: "+err)
                    messagebox.showinfo("Archive verification" if report.passed else "Archive REJECTED",
                                       ("PASS — all checks succeeded." if report.passed else "FAILED:\n"+"\n".join(failed)))
                elif event[0]=="error":
                    self._set_busy(False)
                    self._log("BLOCKED — "+event[1])
                    messagebox.showerror("Quality Gate / Build failed",event[1])
        except queue.Empty:
            pass
        self.after(150,self._poll)


def main():
    Studio().mainloop()


if __name__=="__main__":
    main()
