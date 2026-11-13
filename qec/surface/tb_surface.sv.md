# Algorithmic core RTL test
Used by sim.py with generated shot vectors. The missing core first failed xelab.
Checks exact Python algorithm predictions for zero, single detector, every graph
edge, seeded Stim and dense random syndromes. Independently timestamps acceptance
and result availability against the hardware cycles counter; checks held output
under backpressure and reset abort/reacceptance. Drive inputs on falling edges
and inspect registered outputs after NBA updates. Reset release needs a delta
settling delay before checking combinational in_ready.
