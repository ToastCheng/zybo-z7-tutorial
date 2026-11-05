# Surface SoC timing and pins
Preserves the known board LED pins and PS-generated FCLK clock constraints.
DDR/UART1 use dedicated PS pins from the board preset. All mailbox/decoder state
shares FCLK_CLK0; no PL UART or external clock pins are introduced.
