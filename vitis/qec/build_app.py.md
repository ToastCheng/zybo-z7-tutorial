# Build ARM application
Run `/home/toastcheng/amd/2025.2/Vitis/bin/vitis -s vitis/qec/build_app.py`.
Reuses the established ps_hello unified-Vitis platform/domain workflow with
qec paths/names. Requires build/qec_soc.xsa from the SoC build.
Workspace build/vitis_ws, qec_platform and qec_app.
No boot image or persistent flash is generated.
