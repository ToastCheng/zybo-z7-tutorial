# Same-clock PS/PL bridge
Both AXI GPIO channels and decoder use PS FCLK_CLK0, so no multi-clock bus
sampling is used. PS writes syndrome[7:0] and flips request[8] atomically;
it must hold that word until status[0] matches request. status[1] is prediction,
status[17:2] is a real free-running timestamp difference, not core schedule metadata.
The observer samples out_valid one edge after its first availability; subtract
that one observer cycle to report acceptance-to-availability. Testbench independently
checks both edges (2 cycles); completion register visibility takes 3 cycles.
ctrl[9] synchronously resets the core and status. One outstanding request only.
Reset control must be held long enough for an FCLK edge before release.
