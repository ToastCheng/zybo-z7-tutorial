#------------------------------------------------------------------------------
# build_app.py
# Phase 11 Vitis build script (Vitis unified IDE, 2025.2).
#
# Usage (from the repository root):
#   vitis -s vitis/audio_fx/build_app.py        (or: make app APP=audio_fx)
#
# Creates a standalone (bare-metal) platform from build/audio_fx_soc.xsa,
# creates the audio_fx application, drops our source in, and builds the ELF.
# All generated files live under build/vitis_ws/ (git-ignored).
#------------------------------------------------------------------------------

import glob
import os
import sys

import vitis

WORKSPACE = "build/vitis_ws"
XSA = "build/audio_fx_soc.xsa"
PLATFORM_NAME = "audio_fx_platform"
APP_NAME = "audio_fx_app"
SRC_DIR = os.path.abspath("vitis/audio_fx/src")

if not os.path.exists(XSA):
    sys.exit(f"ERROR: {XSA} not found - run 'make build_soc SOC_TOP=top_audio_fx_soc' first")

client = vitis.create_client()
client.set_workspace(path=WORKSPACE)

#------------------------------------------------------------------------------
# Platform: standalone OS on the first Cortex-A9 core.
#------------------------------------------------------------------------------

try:
    client.delete_component(name=PLATFORM_NAME)
except Exception:
    pass  # platform does not exist yet

platform = client.create_platform_component(
    name=PLATFORM_NAME,
    hw_design=os.path.abspath(XSA),
    os="standalone",
    cpu="ps7_cortexa9_0",
)
platform.build()

xpfm = glob.glob(
    os.path.join(WORKSPACE, PLATFORM_NAME, "export", PLATFORM_NAME, "*.xpfm")
)
if not xpfm:
    sys.exit("ERROR: platform export (.xpfm) not found after platform build")

#------------------------------------------------------------------------------
# Application: create from the hello_world template (the standalone domain
# has no "empty" template), swap in our source so vitis/audio_fx/src/main.c
# stays the single source of truth, and build.
#------------------------------------------------------------------------------

try:
    client.delete_component(name=APP_NAME)
except Exception:
    pass  # app does not exist yet

app = client.create_app_component(
    name=APP_NAME,
    platform=os.path.abspath(xpfm[0]),
    domain="standalone_ps7_cortexa9_0",
    template="hello_world",
)

app.remove_files(files=["src/helloworld.c"])
app.import_files(from_loc=SRC_DIR, dest_dir_in_cmp="src")

# remove_files deletes the file but leaves it in USER_COMPILE_SOURCES;
# drop the stale reference or CMake configuration fails.
user_cfg = os.path.join(WORKSPACE, APP_NAME, "src", "UserConfig.cmake")
with open(user_cfg) as f:
    cfg = f.read()
with open(user_cfg, "w") as f:
    f.write(cfg.replace('"helloworld.c"\n', ""))

app.build()

elf = glob.glob(os.path.join(WORKSPACE, APP_NAME, "build", "*.elf"))
if not elf:
    sys.exit("ERROR: ELF not found after app build")

print(f"Build complete: {elf[0]}")
