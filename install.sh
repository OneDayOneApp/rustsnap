#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP="$HOME/Applications/RustSnap.app"
"$ROOT/scripts/build-app.sh" "$APP"

# Preserve the preferences domain and login-agent label during the display-name migration.
python3 - "$ROOT" "$APP" <<'MIGRATE'
from pathlib import Path
import plistlib,shutil,sys
root,app=map(Path,sys.argv[1:])
agent=Path.home()/"Library/LaunchAgents/dev.local.rustsnip.plist"
if agent.exists():
    data=plistlib.loads(agent.read_bytes())
    data["ProgramArguments"]=[str(app/"Contents/MacOS/RustSnap"),"--background"]
    agent.write_bytes(plistlib.dumps(data))
old=Path.home()/"Applications/RustSnip.app"
if old.exists():
    backup=root/"qa/app-backups/RustSnip.app"
    backup.parent.mkdir(parents=True,exist_ok=True)
    if not backup.exists():shutil.move(str(old),str(backup))
MIGRATE
