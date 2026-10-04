# Continuous reader, early Engram table reads and a conditional read-ahead prior — qualification, October 4

**73.27 prompt tokens/s at pp512/tg512** against **68.85** for the published
`v41-stack-20260930` binary in the same session (**+6.4%**, BAAB), and **73.16** against
**68.67** at pp512/tg200 (**+6.5%**, ABBA), with **byte-identical output on every arm**.
Steady decode in the same arms: 20.12 / 20.12 tok/s at 512/512 (-0.02%) and 19.61 / 19.20
at 512/200 (-2.07%); nothing in this profile touches the decode path, and the decode numbers of
identical configurations drifted by about 6% over this afternoon on a machine with 20 days of uptime (see the
limits below). M5 Max, 128 GiB, internal SSD and two Thunderbolt 5 NVMe enclosures. Release: `v41-stack-20261004`.

**Cache caveat.** Every arm here ran with a 3,600-expert cache on both sides: the champion's 4,600-expert cache passed one
probe and tripped the swap-growth guard on the next engine start (4.3 GB of swap in use, no reboot, at KP's request).
The profile still requests 4,600 experts; decode rates on both sides are therefore below the published champion
(23.26 at 512/512), and every comparison is paired within its group. Prefill does not depend on the cache size
beyond a percent or two.

| Group | Order | Control prefill | Candidate prefill | Gain | Steady decode A / B | Pair deltas |
|---|---|---:|---:|---:|---|---|
| Qualification 512/512 | BAAB | 68.85 | **73.27** | **+6.4%** | 20.12 / 20.12 (-0.02%) | +4.30, +4.53 |
| Qualification 512/200 | ABBA | 68.67 | **73.16** | **+6.5%** | 19.61 / 19.20 (-2.07%) | +3.93, +5.04 |
| Screen: reader + early Engram reads vs the tag build | ABAB | 69.19 | **70.70** | **+2.2%** | 20.16 / 20.21 (+0.22%) | +1.70, +1.33 |
| Screen: conditional prior vs the same build without it | ABAB | 71.19 | **73.43** | **+3.1%** | 20.22 / 19.52 (-3.41%) | +1.77, +2.70 |
| Single lever, closed: split router (bit-exact, no gain) | ABAB | 71.11 | **72.18** | **+1.5%** | 19.70 / 19.05 (-3.30%) | +1.16, +0.98 |

## What changed

Three opt-in switches, all read scheduling; routing, weights, kernels and rounding are untouched, which is why every
arm reproduces the published reference output hash.

1. **Early Engram table reads** (`DS4_ARGODRIVE_ENGRAM_PREFETCH_MIN=1`, `DS4_ARGODRIVE_ENGRAM_BATCH_READERS=128`).
   Upstream overlaps the two Engram row-table reads with the layer sweep only for prompts of 1,024 tokens or more; at
   512 tokens the sweep read them synchronously at layers 1 and 14. With the read-ahead staging keeping the drive queues
   full of large expert reads, each of the 12,288 random 264-byte reads per table waited behind them, and the two
   stalls cost 470–500 ms each on one drive. The first switch lowers upstream's threshold so both tables are read on
   its prefetch thread from the sweep start; the second issues those reads from 128 threads instead of a 16-wide
   dispatch so the first table lands inside layer 0. Same rows, same bytes, same output slots.
2. **Continuous prefill reader** (`DS4_ARGODRIVE_PREFILL_READER=1`). Persistent reader lanes carry the next layer's
   read-ahead straight into the layer's top-up instead of one staging thread per layer: experts that landed count as hits,
   the rest become priority work for lanes that are already running. It removes the 5–11 ms per layer that the
   30 September path spent starting and stopping threads.
3. **Conditional read-ahead prior** (`DS4_ARGODRIVE_COOC=file`). The 30 September hotlist ranks the next layer's experts
   by their overall frequency in 19 other prompts. The prior shipped here tabulates, from per-token routing of the same
   19 prompts, how often an expert at layer L+1 follows each expert at layer L, and ranks the next layer by this
   prompt's own layer-L routing counts (the hotlist stays the fallback for layer 0). On the benchmark prompt the
   precision of the first 130 experts read ahead rises from 76.7% to 82.9% (oracle 99.8%). Read order only.

The three-drive prefill is drive-bound: on the candidate arm the lanes read 177 GB per prompt (149.5 GB of selected
experts plus read-ahead that the layer did not need), 6.95 s of a 7.23 s prompt at the measured 25.5 GB/s ceiling.
Only precision moved it; a split router (attention and router in two token halves so the first half's ids start
the reads early) was made bit-exact — the second half keeps the first half's raw keys in place and both halves use
the whole chunk's compressed-key count — and measured +1.5%: it lengthened
the GPU window more than the certain reads shortened the top-up. It stays in the source as an opt-in switch.

## One-drive diagnostics (60 generated tokens, CPU stage trace on; not qualification arms)

| Arm | Build / switches | Prompt tok/s | Engram wait layer 1 / 14 (ms) | Output |
|---|---|---:|---|---|
| eng1004-B1 | ENGRAM_PREFETCH_MIN=1 (16 GCD readers), reader on by default in that build | 40.09 | 434 / 0 | be5708786e61 |
| eng1004-B2 | ENGRAM_PREFETCH_MIN=1 (16 GCD readers), reader on by default in that build | 41.05 | 420 / 0 | be5708786e61 |
| eng1004-A1 | control: upstream threshold (sync Engram reads at 512 tokens), reader on by default in that build | 39.87 | 473 / 484 | be5708786e61 |
| eng1004-A2 | control: upstream threshold (sync Engram reads at 512 tokens), reader on by default in that build | 39.78 | 478 / 481 | be5708786e61 |
| eng1004b-C1 | ENGRAM_PREFETCH_MIN=1 + ENGRAM_BATCH_READERS=128 | 40.98 | 0 / 0 | be5708786e61 |
| eng1004b-C2 | ENGRAM_PREFETCH_MIN=1 + ENGRAM_BATCH_READERS=128 | 41.49 | 0 / 0 | be5708786e61 |
| eng1004b-B1 | ENGRAM_PREFETCH_MIN=1 (16 GCD readers) | 40.14 | 458 / 0 | be5708786e61 |
| eng1004b-B2 | ENGRAM_PREFETCH_MIN=1 (16 GCD readers) | 40.68 | 451 / 0 | be5708786e61 |
| eng1004b-A1 | control | 39.94 | 480 / 493 | be5708786e61 |
| eng1004b-A2 | control | 39.84 | 488 / 492 | be5708786e61 |
| eng1004c-D1 | profile v41-stack-20261004 (reader + Engram switches) | 41.55 | 0 / 0 | be5708786e61 |
| eng1004c-D2 | profile v41-stack-20261004 (reader + Engram switches) | 41.71 | 0 / 0 | be5708786e61 |
| eng1004c-A1 | profile v41-stack-20260930 | 40.18 | 477 / 491 | be5708786e61 |
| eng1004c-A2 | profile v41-stack-20260930 | 40.20 | 469 / 492 | be5708786e61 |

## Evidence and limits

[All timing CSVs](arms/) · [Machine-readable results](results.json) · [Exact profile](profile.json) ·
[Source checksums](source-sha256.json) · `python3 verify-results.py`

Control arms are the published tag build; candidate arms are this source revision with the switches above,
interleaved in the orders shown, one arm per process, cold start each time. Every arm kept the full 3,600-expert
cache, had zero swap growth and held 1,620 MHz active GPU clocks during decode; two earlier qualification attempts
were stopped by the clock gate (1,475 and 1,070 MHz during a thermally loaded hour) and are not in this package.
All outputs match the historical SHA-256 for their length. Prefill is the rate ds4-bench reports for the
512-token prompt; it excludes model startup.

Not measured here: the 4,600-expert cache, other prompt lengths (the read-ahead only applies to the selective path,
prompts of at most 512 tokens per chunk), or upstream ds4. The conditional prior is built from text that does not
overlap the benchmark prompt; a prior built from different text changes speed, not results.
