# QEC SoC constraints
Uses board user LED pins M14/M15/G14/D18, LVCMOS33. No external PL clock or
UART pins are needed: generated PS IP constrains FCLK_CLK0 and the board
preset configures dedicated PS UART1 MIO pins wired to onboard FTDI USB.
