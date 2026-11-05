# QEC PS/PL top
Connects the actual Zynq PS wrapper's GPIO, common FCLK and synchronized reset
to qec_ps_bridge. LED0 mirrors completion, LED1 prediction. Hard PS DDR/MIO
use dedicated pins configured by the board preset. lut.mem is added as a project
memory source; the default standalone core table is unchanged.
