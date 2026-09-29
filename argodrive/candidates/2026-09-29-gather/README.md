# 29 September session — no new champion; the GPU-driven schedule and the last cheap knobs, measured

Target set for the day: 26 tok/s at pp512/tg512 from the 23.26 of `v41-stack-20260928`. Not reached. Every arm
here is output-identical to the published reference, zero swap growth on retained arms, 1,620 MHz GPU clock.
The engine gains four opt-in switches, all off by default; the profile does not change.

## What was built and what it measured (512-token prompt, 200 generated, interleaved arms)

| Lever | Result | Verdict |
|---|---|---|
| GPU-driven routed MoE, address-table kernels behind a shared-event wait with a residency set over the expert cache | swap guard at decode start (+3 GB): making the 85 GiB cache resident wires it at once | not viable on 128 GB; kernels removed |
| Deferred join, explicit slabs, shared-event GPU wait (`DS4_ARGODRIVE_GPU_GATHER=1`, build 696ca4b1) | 21.42 steady vs a 22.6–22.9 baseline | −6% |
| Deferred join, held command buffer committed after the join (same switch, build 538aa0ca and later) | 21.31; per token GPU span 36.2 vs 34.2 ms, expert reads 13.3 vs 11.9 ms, 55 vs 64 command buffers | −6%; the resident-first split is the better schedule |
| `DS4_ARGODRIVE_SLOTS6_NSG=4` (four SIMD groups in the six-expert kernels) | pairs −0.15, −0.56 | −1.6% |
| `DS4_ARGODRIVE_SLOTS6_NSG=1` | pairs +1.21 (depressed control), −0.08 | flat |
| `DS4_ARGODRIVE_APPEND_LOGITS=1` | pairs +0.60 (depressed control), −0.02 | flat |
| `DS4_ARGODRIVE_ENGRAM_ROWS_SPLIT=1` + `DS4_ARGODRIVE_EARLY_FLUSH=1` (no layer-13 drain; commit layer 0 early) | pairs +0.02, −0.37, +0.98 | inconclusive |

The address-table and event variants of the gather were reverted; the held-buffer variant stays in the source
as an opt-in experiment. One screen (`engram-split-invalid`) is retained as a noise-floor sample: its build had
failed and both arms ran the same previous binary, measuring +0.34 and −1.46 tok/s between identical arms.

## Why the target was out of reach today

A token costs about 44 ms: 34.2 ms of GPU kernels (the large matvecs at 69 to 100% of the memory roofline),
about 12 ms of expert-read wall time per token of which 5 to 6 ms stay exposed, and the rest in boundaries
and CPU work. The deferred schedule moved CPU work off the read wait and still lost, because the shipped
path already runs the resident experts during the read and the deferred kernels ran slower. Prediction was
closed the day before. What remains is not bit-exact (fusing the ~1,300 small dispatches) or not software
(memory for a larger expert cache: the machine sits at 126 of 128 GB with the 4,600-expert cache).

## Measurement caveat

Control arms drifted through the session (44.1 → 45.8 ms per token, individual arms as low as 20.6 tok/s)
while GPU clocks, misses and read times stayed flat; the machine had 111 MB unused with kernel_task at 36%.
Screens were read as interleaved pairs only. A reboot is advised before any qualification meant for publication.

[Timing CSVs](arms/) · [Measured results](results.json) · [Source checksums](source-sha256.json) · [Profile export](profile.json)
