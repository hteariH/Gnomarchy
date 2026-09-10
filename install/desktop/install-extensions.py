#!/usr/bin/env python3
import os
import sys
import glob
import shutil
import zipfile
import subprocess
import urllib.request
import json
import io

EXTENSIONS = [
    "dash-to-dock@micxgx.gmail.com",
    "tactile@lundal.io",
    "just-perfection-desktop@just-perfection",
    "blur-my-shell@aunetx",
    "space-bar@luchrioh",
    "tophat@fflewddur.github.io",
    "AlphabeticalAppGrid@stuarthayhurst",
    "appindicatorsupport@rgcjonas.gmail.com",
    # Deployed but left disabled; `gnomarchy tiling enable` turns it on.
    "tilingshell@ferrarodomenico.com",
]

repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
bundled_dir = os.path.join(repo_root, "default", "gnome", "extensions")
override_file = os.path.join(repo_root, "default", "gnome", "00_gnomarchy.gschema.override")

system_ext_dir = "/usr/share/gnome-shell/extensions"
user_ext_dir = os.path.expanduser("~/.local/share/gnome-shell/extensions")
system_schema_dir = "/usr/share/glib-2.0/schemas"

def run_cmd(cmd):
    """Run a command, reporting failure instead of swallowing it.

    These steps used to fail silently, which is how every extension with
    settings shipped without a compiled schema.
    """
    try:
        proc = subprocess.run(cmd, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode != 0:
            err = proc.stderr.decode("utf-8", "replace").strip()
            print(f"    Warning: {' '.join(cmd)} failed: {err}")
        return proc.returncode == 0
    except Exception as e:
        print(f"    Warning: {' '.join(cmd)} raised: {e}")
        return False

def download_extension(uuid):
    url = f"https://extensions.gnome.org/extension-info/?uuid={uuid}&shell_version=50"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
    except Exception:
        url = f"https://extensions.gnome.org/extension-info/?uuid={uuid}"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
    
    dl_path = data.get("download_url")
    if not dl_path:
        raise RuntimeError(f"No download URL for {uuid}")
    dl_url = "https://extensions.gnome.org" + dl_path
    dl_req = urllib.request.Request(dl_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(dl_req, timeout=15) as resp:
        return resp.read()

def install_extension(uuid):
    print(f"  Installing GNOME extension: {uuid}...")
    zip_path = os.path.join(bundled_dir, f"{uuid}.zip")
    zip_bytes = None
    if os.path.exists(zip_path):
        with open(zip_path, "rb") as f:
            zip_bytes = f.read()
    else:
        try:
            zip_bytes = download_extension(uuid)
        except Exception as e:
            print(f"    Warning: failed to fetch {uuid}: {e}")
            return

    # Extract to user directory
    target_user = os.path.join(user_ext_dir, uuid)
    os.makedirs(target_user, exist_ok=True)
    try:
        with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
            zf.extractall(target_user)
    except Exception as e:
        print(f"    Warning: failed to extract to {target_user}: {e}")

    # Extract to system-wide directory if root or writable, or via sudo
    target_sys = os.path.join(system_ext_dir, uuid)
    can_write_sys = os.access(system_ext_dir, os.W_OK) if os.path.exists(system_ext_dir) else False
    is_root = hasattr(os, "geteuid") and os.geteuid() == 0
    if can_write_sys or is_root:
        os.makedirs(target_sys, exist_ok=True)
        try:
            with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
                zf.extractall(target_sys)
        except Exception as e:
            print(f"    Warning: failed to extract to {target_sys}: {e}")
    else:
        run_cmd(["sudo", "mkdir", "-p", target_sys])
        run_cmd(["sudo", "cp", "-r", f"{target_user}/.", target_sys])

    # Compile the extension's OWN schemas directory.
    #
    # GNOME Shell resolves an extension's settings through
    # <extension>/schemas/gschemas.compiled. Compiling only the system schema
    # directory leaves that file missing, and the extension fails to load with
    # GLib.FileError at startup.
    for ext_root in (target_user, target_sys):
        schema_dir = os.path.join(ext_root, "schemas")
        if not glob.glob(os.path.join(schema_dir, "*.gschema.xml")):
            continue
        if os.access(schema_dir, os.W_OK):
            run_cmd(["glib-compile-schemas", schema_dir])
        else:
            run_cmd(["sudo", "glib-compile-schemas", schema_dir])

    # Copy schema files to system schemas
    for schema_file in glob.glob(os.path.join(target_user, "schemas", "*.gschema.xml")):
        dest = os.path.join(system_schema_dir, os.path.basename(schema_file))
        can_write_schema = os.access(system_schema_dir, os.W_OK) if os.path.exists(system_schema_dir) else False
        if can_write_schema or is_root:
            shutil.copy2(schema_file, dest)
        else:
            run_cmd(["sudo", "cp", "-f", schema_file, dest])

def main():
    os.makedirs(user_ext_dir, exist_ok=True)
    for ext in EXTENSIONS:
        install_extension(ext)

    # Copy system-wide GSettings override
    if os.path.exists(override_file):
        dest_override = os.path.join(system_schema_dir, "00_gnomarchy.gschema.override")
        is_root = hasattr(os, "geteuid") and os.geteuid() == 0
        can_write_schema = os.access(system_schema_dir, os.W_OK) if os.path.exists(system_schema_dir) else False
        if can_write_schema or is_root:
            shutil.copy2(override_file, dest_override)
        else:
            run_cmd(["sudo", "cp", "-f", override_file, dest_override])

    # Compile schemas
    is_root = hasattr(os, "geteuid") and os.geteuid() == 0
    can_write_schema = os.access(system_schema_dir, os.W_OK) if os.path.exists(system_schema_dir) else False
    if can_write_schema or is_root:
        run_cmd(["glib-compile-schemas", system_schema_dir])
    else:
        run_cmd(["sudo", "glib-compile-schemas", system_schema_dir])

    print("All GNOME extensions deployed and schemas compiled.")

if __name__ == "__main__":
    main()
