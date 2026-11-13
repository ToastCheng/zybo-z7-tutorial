# Parameterized half-edge union-find and peeling RTL
Core interface: full DETECTORS-bit window with ready/valid, held prediction,
decode_error, and a real 32-bit active-cycle counter. EDGES endpoint/observable
words are a graph ROM, not a syndrome LUT. Vertex DETECTORS is the sole absorbing
boundary; vertex width derives from DETECTORS. Retained state is O(V+E): labels,
root parities, half-edge growth, forest membership, degree and working syndrome.
INIT clears state per shot. CHECK/GROW/RELABEL perform deterministic serial unions;
LEAVES/FIND peel the forest and XOR observable labels; VERIFY rejects remaining
non-boundary parity. Growth sweep limit returns error on unreachable odd clusters.
Cycles count input acceptance to first registered output availability, including
initialization/scans; hold/backpressure adds no core cycles. FCLK configured100MHz.

The algorithm is unweighted, finite-window and serialized. Larger graphs require
parameter/ROM changes and resynthesis, not exponential syndrome-table generation.
It is not a real-time streaming threshold decoder or an optimized parallel UF
engine. d5 simulation verifies wider parameterization; board fit/timing must be
measured separately. The accompanying Python reference fixes scheduling/ties.
