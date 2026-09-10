#!/usr/bin/env python3
"""
Gnomarchy Brave Origin Installer
Downloads official pre-compiled Brave Origin Linux binary from GitHub releases,
installs it to /opt/brave-origin, sets up system symlinks, desktop entry, and default browser handler.
"""

import os
import sys
import shutil
import zipfile
import subprocess
import urllib.request

INSTALL_DIR = "/opt/brave-origin"
DESKTOP_DIR = "/usr/share/applications"
ICON_DIR = "/usr/share/icons/hicolor/128x128/apps"
PIXMAPS_DIR = "/usr/share/pixmaps"

def log(msg):
    print(f"  [Brave Origin] {msg}")

def get_release_urls():
    """Resolves latest release tag via GitHub redirect (immune to API rate limits)."""
    try:
        url = "https://github.com/brave/brave-browser/releases/latest"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            final_url = resp.geturl()
            tag = final_url.split("/")[-1]
            ver = tag.lstrip("v")
            log(f"Detected latest release: {tag}")
            
            origin_url = f"https://github.com/brave/brave-browser/releases/download/{tag}/brave-origin-{ver}-linux-amd64.zip"
            browser_url = f"https://github.com/brave/brave-browser/releases/download/{tag}/brave-browser-{ver}-linux-amd64.zip"
            return [origin_url, browser_url]
    except Exception as e:
        log(f"Redirect resolution failed: {e}")
        # Hardcoded baseline fallback
        return [
            "https://github.com/brave/brave-browser/releases/download/v1.94.121/brave-origin-1.94.121-linux-amd64.zip",
            "https://github.com/brave/brave-browser/releases/download/v1.94.121/brave-browser-1.94.121-linux-amd64.zip"
        ]

def download_and_extract(urls):
    temp_zip = "/tmp/brave-origin.zip"
    downloaded = False

    for dl_url in urls:
        log(f"Attempting download from {dl_url}...")
        try:
            req = urllib.request.Request(dl_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=120) as resp, open(temp_zip, "wb") as out_file:
                shutil.copyfileobj(resp, out_file, length=128 * 1024)
            downloaded = True
            log("Download successful.")
            break
        except Exception as e:
            log(f"Download failed for {dl_url}: {e}")

    if not downloaded:
        raise RuntimeError("Could not download Brave Origin from any release URL.")

    log(f"Extracting to {INSTALL_DIR}...")
    os.makedirs(INSTALL_DIR, exist_ok=True)
    with zipfile.ZipFile(temp_zip) as zf:
        zf.extractall(INSTALL_DIR)

    if os.path.exists(temp_zip):
        os.remove(temp_zip)

def setup_binaries_and_symlinks():
    possible_bins = ["brave", "brave-browser", "brave-origin"]
    main_bin = None

    for name in possible_bins:
        path = os.path.join(INSTALL_DIR, name)
        if os.path.isfile(path):
            main_bin = path
            break

    if not main_bin:
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

    # brave-browser.desktop exists only as a compatibility alias so tools that
    # look for that id still resolve. It must be hidden from the launcher,
    # otherwise the dash and app grid show two identical Brave entries.
    with open(browser_desktop_path, "w", encoding="utf-8") as f:
        alias = desktop_content.rstrip("\n") + "\nNoDisplay=true\n"
        f.write(alias)

    os.chmod(desktop_path, 0o644)
    os.chmod(browser_desktop_path, 0o644)
    log(f"Installed desktop entries at {desktop_path} and {browser_desktop_path}")

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
    urls = get_release_urls()
    try:
        download_and_extract(urls)
        if setup_binaries_and_symlinks():
            setup_desktop_and_icons()
            log("Brave Origin preinstalled successfully.")
        else:
            sys.exit(1)
    except Exception as e:
        log(f"Preinstallation failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
