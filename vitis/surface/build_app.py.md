# Surface ARM build
Run Vitis unified2025.2 `vitis -s vitis/surface/build_app.py` after the SoC build.
Reuses the tested ps_hello platform/domain/CMake flow with surface names, sources
and build/surface_soc.xsa. ELF: build/vitis_ws/surface_app/build/surface_app.elf.
Generated workspace is ignored; no boot image/flash command is generated.
