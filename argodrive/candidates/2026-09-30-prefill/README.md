# Prefill read-ahead and two-wave routed MoE — screens, September 30

**67.96 prompt tokens/s at pp512** against **45.34** for the published
`v41-stack-20260928` binary in the same session (**+49.9%**, three interleaved pairs),
with **byte-identical output on every arm** and decode unchanged (20.03 / 20.25
steady tok/s, +1.10%). M5 Max, 128 GiB, internal SSD and two Thunderbolt 5 NVMe enclosures.

**These are screens, not the qualification.** Both sides ran with a 3,600-expert cache: the champion's
4,600-expert cache tripped the swap-growth guard on a machine with fifteen days of uptime and 4.6 GB of
swap in use. Decode rates on both sides are therefore below the published champion (23.26 at 512/512).
The 4,600 qualification (512/512 BAAB and 512/200 ABBA, probe-gated) runs after a reboot; until then the
profile `v41-stack-20260930` is a candidate.

| Group | Order | Control prefill | Candidate prefill | Gain | Steady decode A / B | Pair deltas |
|---|---|---:|---:|---:|---|---|
| Read-ahead staging (build 1) | ABAB | 46.27 | **65.44** | **+41.5%** | 19.71 / 19.66 (-0.23%) | +18.88, +19.48 |
| + layer-0 read-ahead (build 2) | ABAB | 46.67 | **65.62** | **+40.6%** | 19.97 / 19.77 (-1.00%) | +19.08, +18.81 |
| + two-wave routed MoE (build 3) | ABAB | 46.63 | **66.34** | **+42.3%** | 19.98 / 19.94 (-0.23%) | +17.23, +22.20 |
| Final binary, three pairs | ABABAB | 45.34 | **67.96** | **+49.9%** | 20.03 / 20.25 (+1.10%) | +22.40, +22.57, +22.77 |

Final-screen arms in order: control 46.68, 45.34, 45.19; candidate 69.08, 67.91, 67.96 tok/s.
The single-lever check `topup-parts` (top-up read in two parts, `DS4_ARGODRIVE_PREFILL_WAVES=2`) measured
68.87 against 69.19 for one part
(-0.5%) and is not part of the profile.

## What changed

Prefill on this configuration stages only the experts the router selected, which cannot start before the
layer's router has run; the drives therefore idled while the GPU computed the previous layer (measured
2026-09-28: 147 ms of staging and 142 ms of compute per layer, strictly alternating, at 44.3 tok/s).

1. **Read-ahead staging** (`DS4_ARGODRIVE_PREFILL_HOT=384`, `DS4_ARGODRIVE_HOTLIST=file`). After a layer is
   staged, a thread reads the next layer's experts in the order of a hotness prior into the spare staging
   set while the GPU works. When the router ids arrive it is stopped; experts whose three tensors landed are
   kept and only the rest are read. The prior is a per-layer ranking built from prefill selections of 19
   other prompts ([provenance](../../reproduce/hotlists/README.md)); it decides read order only.
2. **Two-wave routed MoE** (`DS4_ARGODRIVE_PREFILL_WAVES=1`). The experts already on hand are encoded and
   committed before the top-up read, so the GPU works during it; the remaining experts follow. This is
   bit-exact by construction: the grouped map kernel skips ids that match no expert, every (token, slot)
   row is written exactly once by whichever wave owns it, and the fixed-order slot sum runs over the
   complete rows.

Same bytes from the same verified replicas through the same reader, same kernels, same rounding; only the
order and overlap of reads changed. Expert selection, weights and arithmetic are untouched, which is why
every arm reproduces the published reference output hash.

## Evidence and limits

[All timing CSVs](arms/) · [Machine-readable results](results.json) · [Exact profile](profile.json) ·
[Source checksums](source-sha256.json) · `python3 verify-results.py`

Control arms are the published tag build; candidate arms are this source revision with the switches above,
interleaved in the orders shown, one arm per process, cold start each time. Every arm kept the full cache,
had zero swap growth and held 1,620 MHz active GPU clocks; all outputs match the historical SHA-256 for
200 generated tokens. Prefill is the rate ds4-bench reports for the 512-token prompt; it excludes model
startup. A fresh process still pays about 0.2 s of first-layer cost that the trace attributes to first use of
the freshly allocated staging buffers; it is inside every number here.

Not measured here: the 4,600-expert cache, 512-token generation, other prompt lengths (the read-ahead only
applies to the selective path, prompts of at most 512 tokens per chunk), or upstream ds4. The prior is
domain-sensitive: a 37-prompt list with English technical prose covered fewer of this prompt's selections
than the 19-prompt list and is not shipped.
