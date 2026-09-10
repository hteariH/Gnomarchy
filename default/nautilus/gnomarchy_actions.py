import os
import subprocess
import urllib.parse
from gi.repository import Nautilus, GObject

class GnomarchyMenuProvider(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()

    def _get_path(self, file_info):
        uri = file_info.get_uri()
        if uri.startswith("file://"):
            return urllib.parse.unquote(uri[7:])
        return None

    def _notify(self, title, msg, icon="system-run"):
        subprocess.Popen(["notify-send", "-i", icon, title, msg])

    def _run_bg(self, cmd, success_msg=None, icon="system-run"):
        def task():
            try:
                res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                if res.returncode == 0:
                    if success_msg:
                        self._notify("Gnomarchy Action", success_msg, icon)
                else:
                    self._notify("Gnomarchy Action Failed", res.stderr[:200] if res.stderr else "Unknown error", "dialog-error")
            except Exception as e:
                self._notify("Gnomarchy Error", str(e), "dialog-error")

        import threading
        t = threading.Thread(target=task, daemon=True)
        t.start()

    # --- Video Callbacks ---
    def _cb_compress_video(self, menu, files):
        for f in files:
            p = self._get_path(f)
            if not p: continue
            base, _ = os.path.splitext(p)
            out_p = f"{base}_compressed.mp4"
            self._notify("Compressing Video", f"Processing {os.path.basename(p)}...", "video-x-generic")
            cmd = [
                "ffmpeg", "-y", "-i", p,
                "-c:v", "libx264", "-crf", "28", "-preset", "fast",
                "-c:a", "aac", "-b:a", "128k",
                out_p
            ]
            self._run_bg(cmd, f"Saved compressed video:\n{os.path.basename(out_p)}", "video-x-generic")

    def _cb_convert_gif(self, menu, files):
        for f in files:
            p = self._get_path(f)
            if not p: continue
            base, _ = os.path.splitext(p)
            out_p = f"{base}.gif"
            self._notify("Generating GIF", f"Processing {os.path.basename(p)}...", "image-x-generic")
            filter_str = "fps=15,scale=640:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"
            cmd = ["ffmpeg", "-y", "-i", p, "-vf", filter_str, out_p]
            self._run_bg(cmd, f"Saved GIF:\n{os.path.basename(out_p)}", "image-x-generic")

    def _cb_extract_mp3(self, menu, files):
        for f in files:
            p = self._get_path(f)
            if not p: continue
            base, _ = os.path.splitext(p)
            out_p = f"{base}.mp3"
            self._notify("Extracting Audio", f"Processing {os.path.basename(p)}...", "audio-x-generic")
            cmd = ["ffmpeg", "-y", "-i", p, "-vn", "-acodec", "libmp3lame", "-q:a", "2", out_p]
            self._run_bg(cmd, f"Saved MP3:\n{os.path.basename(out_p)}", "audio-x-generic")

    # --- Image Callbacks ---
    def _cb_convert_webp(self, menu, files):
        for f in files:
            p = self._get_path(f)
            if not p: continue
            base, _ = os.path.splitext(p)
            out_p = f"{base}.webp"
            cmd = ["magick", p, out_p]
            self._run_bg(cmd, f"Converted to WebP:\n{os.path.basename(out_p)}", "image-x-generic")

    def _cb_strip_exif(self, menu, files):
        for f in files:
            p = self._get_path(f)
            if not p: continue
            if subprocess.run(["which", "exiftool"], stdout=subprocess.DEVNULL).returncode == 0:
                cmd = ["exiftool", "-all=", "-overwrite_original", p]
            else:
                cmd = ["magick", p, "-strip", p]
            self._run_bg(cmd, f"Stripped metadata:\n{os.path.basename(p)}", "image-x-generic")

    def _cb_resize_1080p(self, menu, files):
        for f in files:
            p = self._get_path(f)
            if not p: continue
            base, ext = os.path.splitext(p)
            out_p = f"{base}_1080p{ext}"
            cmd = ["magick", p, "-resize", "1920x1080>", out_p]
            self._run_bg(cmd, f"Resized to 1080p:\n{os.path.basename(out_p)}", "image-x-generic")

    # --- General Callbacks ---
    def _cb_localsend(self, menu, files):
        paths = [self._get_path(f) for f in files if self._get_path(f)]
        if paths:
            if subprocess.run(["which", "localsend"], stdout=subprocess.DEVNULL).returncode == 0:
                subprocess.Popen(["localsend"] + paths)
            else:
                subprocess.Popen(["flatpak", "run", "org.localsend.localsend_app"] + paths)

    def _cb_edit_micro(self, menu, files):
        paths = [self._get_path(f) for f in files if self._get_path(f)]
        if paths:
            subprocess.Popen(["gnome-terminal", "--", "micro"] + paths)

    def get_file_items(self, files):
        if not files:
            return []

        # Categorize
        has_video = any(f.get_mime_type().startswith("video/") for f in files)
        has_image = any(f.get_mime_type().startswith("image/") for f in files)

        top_menu_item = Nautilus.MenuItem(
            name="Gnomarchy::TopMenu",
            label="Gnomarchy Actions",
            tip="Gnomarchy System & Media Utilities"
        )
        submenu = Nautilus.Menu()
        top_menu_item.set_submenu(submenu)

        # Video sub-items
        if has_video:
            item_compress = Nautilus.MenuItem(name="Gnomarchy::CompressVideo", label="Compress Video (Fast / Discord)")
            item_compress.connect("activate", self._cb_compress_video, files)
            submenu.append_item(item_compress)

            item_gif = Nautilus.MenuItem(name="Gnomarchy::ConvertGif", label="Convert to Animated GIF")
            item_gif.connect("activate", self._cb_convert_gif, files)
            submenu.append_item(item_gif)

            item_mp3 = Nautilus.MenuItem(name="Gnomarchy::ExtractMp3", label="Extract Audio (MP3)")
            item_mp3.connect("activate", self._cb_extract_mp3, files)
            submenu.append_item(item_mp3)

        # Image sub-items
        if has_image:
            item_webp = Nautilus.MenuItem(name="Gnomarchy::ConvertWebp", label="Convert to WebP")
            item_webp.connect("activate", self._cb_convert_webp, files)
            submenu.append_item(item_webp)

            item_strip = Nautilus.MenuItem(name="Gnomarchy::StripExif", label="Strip EXIF / Privacy Metadata")
            item_strip.connect("activate", self._cb_strip_exif, files)
            submenu.append_item(item_strip)

            item_resize = Nautilus.MenuItem(name="Gnomarchy::Resize1080p", label="Resize to 1080p Max")
            item_resize.connect("activate", self._cb_resize_1080p, files)
            submenu.append_item(item_resize)

        # General items
        item_micro = Nautilus.MenuItem(name="Gnomarchy::EditMicro", label="Edit in Micro (Terminal)")
        item_micro.connect("activate", self._cb_edit_micro, files)
        submenu.append_item(item_micro)

        item_localsend = Nautilus.MenuItem(name="Gnomarchy::LocalSend", label="Share via LocalSend")
        item_localsend.connect("activate", self._cb_localsend, files)
        submenu.append_item(item_localsend)

        return [top_menu_item]
