# V4.1 stack, 28 September — post-MoE flush and eviction pre-scan, qualified against the published stack binary

**23.260 steady tok/s at pp512/tg512**, generation-inclusive **22.755**,
against **22.920 / 22.470** for the published `v41-stack-20260927` binary built from its tag and
run in the same session with the same profile and 4,600-expert cache: **+1.48% steady / +1.27% inclusive** (BAAB, pairs +0.30, +0.38).
At pp512/tg200 (ABBA): **22.940 against 22.555**, +1.71% (pairs +0.33, +0.44).
Output is byte-identical to the published references on every arm in this package. Profile: `v41-stack-20260928`.

This is a small, real gain, not the 10% the session set out for. The rest of this page records what was
measured, including the levers that lost.

| Prompt / output tokens | Order | Published stack steady | Candidate steady | Steady gain | Published inclusive | Candidate inclusive | Inclusive gain |
|---|---|---:|---:|---:|---:|---:|---:|
| Main / 512 | BAAB | 22.920 | **23.260** | **+1.48%** | 22.470 | **22.755** | **+1.27%** |
| Main / 200 | ABBA | 22.555 | **22.940** | **+1.71%** | 21.485 | **21.810** | **+1.51%** |

The 512-token candidate runs were **23.18 / 23.34 steady** and **22.65 / 22.86 inclusive**; the
published binary ran **22.88 / 22.96 steady** and **22.44 / 22.50 inclusive**. An earlier build of the
same candidate with the flush alone measured +1.27% at 512/512 (pairs +0.37, +0.21) and
+0.58% at 512/200 (pairs +0.18, +0.08); those arms are retained below.

Steady excludes the first decode step; inclusive includes it. Both exclude startup and prefill. Two
repeats give an observed range, not a confidence interval. This compares our previous published binary,
**not upstream ds4**; the [drive ladder against pinned upstream](../2026-09-27-ladder/README.md) was
measured with the 27 September profile and is not re-run here. No broad model-quality or chat/server
claim is made. Keepalive remains enabled and increases power consumption.

## What the profile adds

`v41-stack-20260928` is `v41-stack-20260927` plus exactly:

```sh
DS4_ARGODRIVE_POST_MOE_FLUSH=1
DS4_ARGODRIVE_VICTIM_PRESCAN=1
```

**Post-MoE flush.** After a layer that waited for expert reads, the routed MoE, its residual add and
rounding are committed as their own command buffer, so the GPU starts them while the CPU encodes the
next layer's attention instead of after it. Mode 2 (every layer) measured the same within noise and adds
buffer boundaries, so mode 1 is the profile. **Eviction pre-scan.** While the CPU spins on the router
mailbox it ranks the eight lowest-hotness reusable cache entries; a miss then takes the first candidate
that still passes every check the full scan applies (reusable, not in flight, not protected, unchanged
hotness and age) and falls back to the full scan otherwise. On the qualified arms every eviction took a
pre-ranked candidate and none fell back. Neither change touches arithmetic, expert selection or weights.

## Every lever screened, same day, interleaved pairs on the candidate binary

| Lever | What it changes | Screen | Steady medians A → B | Pair deltas |
|---|---|---|---:|---:|
| Post-MoE flush, miss layers | commit after the routed MoE on layers that waited for reads | 512/200 ABAB | 22.410 → 22.720, **+1.38%** | +0.32, +0.30 |
| Post-MoE flush, all layers | commit after the routed MoE of every layer (first pair follows a swap incident, see below) | 512/200 ABAB | 21.955 → 22.700, **+3.39%** | +1.26, +0.23 |
| Eviction pre-scan | candidates ranked during the mailbox wait; both arms carry the flush | 512/200 ABAB | 22.725 → 22.835, **+0.48%** | +0.19, +0.03 |
| Next-layer prediction through the mailbox, K=2 | the 15 September predictor with its blocking readbacks replaced by a second mailbox slot; misses 12.22 → 11.37 per token, prediction cost larger than the saving | 512/200 ABAB | 22.280 → 22.060, **-0.99%** | -0.21, -0.23 |
| Prediction, speculative reads only for non-resident experts, K=3 | misses 12.22 → 8.37 per token, but the speculative reads compete with demand reads; stopped after one pair | 512/200 ABAB | 22.420 → 20.590, **-8.16%** | -1.83 |

The missing-only prediction with K=2 was stopped by the swap-growth guard on its first candidate arm and
is retained as excluded. Prediction is closed with data for this cache size: reading the predicted misses
early cuts demand misses by a third but the speculative reads displace resident experts and share the
drives with demand reads, and the prediction itself costs about one millisecond of GPU time per token.

## Where a token goes, measured on the 27 September stack before this session

A one-millisecond CPU sample during decode put the main thread 60% in the mailbox spin (the GPU running
attention and the router), 27% blocked on expert reads at the routed MoE, 3% waiting for the LM head,
and about 10% encoding. Per token that is roughly 34 ms of GPU kernels, 5 to 6 ms of exposed read waits,
3 to 5 ms of command-buffer boundaries and about 2 ms of CPU work. The kernels at the top of the GPU
budget run at 69 to 100% of the measured memory roofline; the remaining GPU inefficiency is about 1,300
small dispatches, whose fusions are not bit-exact and were out of scope. A 10% gain needs the read waits
or the dispatch count to move; neither did today.

## All attempts are retained

[Timing CSVs](arms/) · [Measured results](results.json) · [Source checksums](source-sha256.json) · [Profile export](profile.json)

| Group | Order | Steady tok/s in order | Disposition |
|---|---|---|---|
| final512 | BAAB | 23.18 / 22.88 / 22.96 / 23.34 | qualification |
| final200 | ABBA | 22.59 / 22.92 / 22.96 / 22.52 | qualification |
| flush512 | BAAB | 23.14 / 22.77 / 22.89 / 23.10 | qualification (earlier candidate build, flush only) |
| flush200 | ABBA | 22.53 / 22.71 / 22.56 / 22.48 | qualification (earlier candidate build, flush only) |
| post-moe-flush-miss-layers | ABAB | 22.35 / 22.67 / 22.47 / 22.77 | single lever |
| post-moe-flush-all-layers | ABAB | 21.42 / 22.68 / 22.49 / 22.72 | single lever |
| victim-prescan | ABAB | 22.67 / 22.86 / 22.78 / 22.81 | single lever |
| lookahead-mailbox-k2 | ABAB | 22.23 / 22.02 / 22.33 / 22.10 | single lever (rejected) |
| lookahead-missing-only-k3 | ABAB | 22.42 / 20.59 | single lever (rejected, stopped after one pair) (incomplete) |
| lookahead-missing-only-k2 | ABAB | 22.47 | excluded: swap guard (incomplete) |

A is the published `v41-stack-20260927` binary in the qualification groups. Every retained arm recorded
zero swap growth, the requested cache allocation, 1,620 MHz active GPU clock during decode and the
reference output hash. No build ran and no second engine process existed during any arm. One excluded
arm (`lookahead-missing-only-k2`, arm 2B) was stopped by the swap-growth guard at the start of decode
and swapped about 1.5 GB of other processes out; the arms that followed passed the guard, and the first
`post-moe-flush-all-layers` control arm, which ran right after it, is visibly depressed (21.42).

## Build and reproduce

```sh
git clone --branch v41-stack-20260928 https://github.com/argonautlabsai/ds4-argodrive.git
cd ds4-argodrive
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
xcrun clang --version
make -j4 CC="$(xcrun --find clang)" ds4 ds4-bench ds4-server
python3 argodrive/candidates/2026-09-28-flush/verify-results.py
```

Apple clang 14.0.3 / macOS 26.4 SDK as before. Run the [stack profile command](../../reproduce/V41-STACK.md#run)
with `--profile v41-stack-20260928`; build the control from `v41-stack-20260927` in a separate tree. The
model, receipts, sampler and gates are unchanged from the 27 September package.

Built on [ds4 by antirez and contributors](https://github.com/antirez/ds4). [Credits](../../../CREDITS.md) ·
[Argodrive](https://github.com/argonautlabsai/argodrive).
