#!/usr/bin/env python3
"""
Gnomarchy Brave Origin Installer
Downloads official pre-compiled Brave Origin Linux binary from GitHub releases,
installs it to /opt/brave-origin, sets up system symlinks, desktop entry, and default browser handler.
"""

import os
import sys
import json
import shutil
import zipfile
import subprocess
import urllib.request

API_URL = "https://api.github.com/repos/brave/brave-browser/releases/latest"
INSTALL_DIR = "/opt/brave-origin"
DESKTOP_DIR = "/usr/share/applications"
ICON_DIR = "/usr/share/icons/hicolor/128x128/apps"
PIXMAPS_DIR = "/usr/share/pixmaps"

def log(msg):
    print(f"  [Brave Origin] {msg}")

def get_release_asset():
    req = urllib.request.Request(API_URL, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
    except Exception as e:
        log(f"Failed to query Brave release API: {e}")
        return None

    # Prefer brave-origin, fallback to brave-browser
    origin_asset = None
    browser_asset = None

    for asset in data.get("assets", []):
        name = asset.get("name", "")
        if "linux-amd64.zip" in name:
            if "brave-origin" in name:
                origin_asset = asset
                break
            elif "brave-browser" in name:
                browser_asset = asset

    chosen = origin_asset or browser_asset
    if chosen:
        log(f"Selected asset: {chosen.get('name')}")
        return chosen.get("browser_download_url")
    return None

def download_and_extract(download_url):
    temp_zip = "/tmp/brave-origin.zip"
    log(f"Downloading Brave package from {download_url}...")
    req = urllib.request.Request(download_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as resp, open(temp_zip, "wb") as out_file:
        shutil.copyfileobj(resp, out_file, length=64 * 1024)

    log(f"Extracting to {INSTALL_DIR}...")
    os.makedirs(INSTALL_DIR, exist_ok=True)
    with zipfile.ZipFile(temp_zip) as zf:
        zf.extractall(INSTALL_DIR)

    if os.path.exists(temp_zip):
        os.remove(temp_zip)

def setup_binaries_and_symlinks():
    # Identify the executable binary
    possible_bins = ["brave", "brave-browser", "brave-origin"]
    main_bin = None
    for name in possible_bins:
        path = os.path.join(INSTALL_DIR, name)
        if os.path.isfile(path):
            main_bin = path
            break

    if not main_bin:
        # Check subdirectories
        for root, _, files in os.walk(INSTALL_DIR):
            for name in possible_bins:
                if name in files:
                    main_bin = os.path.join(root, name)
                    break
            if main_bin:
                break

    if not main_bin:
        log("Warning: could not locate brave executable binary inside extracted files.")
        return False

    os.chmod(main_bin, 0o755)

    # Symlink to /usr/local/bin
    os.makedirs("/usr/local/bin", exist_ok=True)
    links = [
        "/usr/local/bin/brave-origin",
        "/usr/local/bin/brave",
        "/usr/local/bin/brave-browser"
    ]
    for link in links:
        try:
            if os.path.islink(link) or os.path.exists(link):
                os.remove(link)
            os.symlink(main_bin, link)
            log(f"Symlinked {link} -> {main_bin}")
        except Exception as e:
            log(f"Error creating symlink {link}: {e}")

    return True

def setup_desktop_and_icons():
    # Find icon
    icon_source = None
    for root, _, files in os.walk(INSTALL_DIR):
        for f in files:
            if f.startswith("product_logo_") and f.endswith(".png"):
                icon_source = os.path.join(root, f)
                break
        if icon_source:
            break

    if icon_source:
        try:
            os.makedirs(ICON_DIR, exist_ok=True)
            os.makedirs(PIXMAPS_DIR, exist_ok=True)
            shutil.copy2(icon_source, os.path.join(ICON_DIR, "brave-origin.png"))
            shutil.copy2(icon_source, os.path.join(PIXMAPS_DIR, "brave-origin.png"))
            shutil.copy2(icon_source, os.path.join(PIXMAPS_DIR, "brave-browser.png"))
        except Exception as e:
            log(f"Error copying desktop icons: {e}")

    # Desktop entry content
    desktop_content = """[Desktop Entry]
Version=1.0
Name=Brave Origin
GenericName=Web Browser
Comment=Access the Internet with debloated privacy
Exec=/usr/local/bin/brave-origin %U
Icon=brave-origin
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
StartupWMClass=brave-browser
"""

    os.makedirs(DESKTOP_DIR, exist_ok=True)
    desktop_path = os.path.join(DESKTOP_DIR, "brave-origin.desktop")
    browser_desktop_path = os.path.join(DESKTOP_DIR, "brave-browser.desktop")

    with open(desktop_path, "w", encoding="utf-8") as f:
        f.write(desktop_content)
    with open(browser_desktop_path, "w", encoding="utf-8") as f:
        f.write(desktop_content)

    os.chmod(desktop_path, 0o644)
    os.chmod(browser_desktop_path, 0o644)
    log(f"Installed desktop entries at {desktop_path} and {browser_desktop_path}")

    # Configure default browser via xdg
    try:
        subprocess.run(["xdg-settings", "set", "default-web-browser", "brave-origin.desktop"],
                       check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        subprocess.run(["xdg-mime", "default", "brave-origin.desktop", "x-scheme-handler/http"],
                       check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        subprocess.run(["xdg-mime", "default", "brave-origin.desktop", "x-scheme-handler/https"],
                       check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        subprocess.run(["xdg-mime", "default", "brave-origin.desktop", "text/html"],
                       check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except Exception:
        pass

def main():
    if os.geteuid() != 0:
        print("Brave Origin installation requires root privileges.")
        sys.exit(1)

    url = get_release_asset()
    if not url:
        log("Could not find release asset from GitHub API.")
        sys.exit(1)

    try:
        download_and_extract(url)
        if setup_binaries_and_symlinks():
            setup_desktop_and_icons()
            log("Brave Origin installed successfully.")
        else:
            sys.exit(1)
    except Exception as e:
        log(f"Installation failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
