#!/usr/bin/python3
"""Register the workspace visibility helper for one unpacked Brave extension."""
import argparse
import json
import os
from pathlib import Path
import re
from tempfile import NamedTemporaryFile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("extension_id", help="ID displayed in brave://extensions")
extension_id = parser.parse_args().extension_id
if not re.fullmatch(r"[a-p]{32}", extension_id):
    parser.error("expected a 32-character Brave extension ID")

name = "io.github.bspwm.brave_pip"
config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
directory = config / "BraveSoftware/Brave-Browser/NativeMessagingHosts"
directory.mkdir(parents=True, exist_ok=True)
manifest = directory / f"{name}.json"
if manifest.exists():
    parser.exit(1, f"Existing registration at {manifest}. Back it up before replacing it.\n")
with NamedTemporaryFile(mode="w", dir=directory, delete=False) as file:
    json.dump({
        "name": name,
        "description": "Read desktop visibility for automatic PiP",
        "path": str(Path(__file__).resolve().with_name("desktop_host.py")),
        "type": "stdio",
        "allowed_origins": [f"chrome-extension://{extension_id}/"],
    }, file, indent=2)
    file.write("\n")
temporary = Path(file.name)
try:
    manifest.hardlink_to(temporary)
except FileExistsError:
    parser.exit(1, f"Existing registration at {manifest}. Back it up before replacing it.\n")
finally:
    temporary.unlink()
print(f"Registered {manifest}. Reload the extension in Brave.")
