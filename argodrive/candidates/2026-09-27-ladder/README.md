# Drive ladder against pinned upstream — September 27

One interleaved session on the M5 Max with 128 GiB: pinned upstream ds4 (`bd66c40`, phase markers only) on the internal SSD against this fork's `v41-stack-20260927` profile on the internal SSD alone, with one enclosure and with two. 512-token prompt, 200 generated, greedy, 4,096 context allocation, fresh process and empty expert cache per arm. Sequence `U,S1,U,S2,U,S3,S3,U,S2,U,S1,U`: every fork rung is bracketed by upstream arms.

| Rung | Runs | Prompt processing tok/s | Steady decode tok/s | Incl. first step tok/s | First decode step ms |
|---|---:|---:|---:|---:|---:|
| upstream ds4 bd66c40, internal SSD only | 6 | 17.96 | 10.18 | 9.90 | 646 |
| this fork, internal SSD only (no replicas) | 2 | **30.98** (1.72×) | **18.66** (1.83×) | 17.45 (1.76×) | 799 |
| this fork, internal + one enclosure | 2 | 36.88 (2.05×) | 21.05 (2.07×) | 19.54 (1.97×) | 780 |
| this fork, internal + two enclosures | 2 | **42.41** (2.36×) | **22.25** (2.19×) | 20.74 (2.10×) | 694 |

Output is byte-identical to upstream on all 12 arms. The internal-only fork rung uses no replicas: same laptop, same single SSD, same model file as the control, so its multiplier is software only. Enclosure rungs add byte-identical verified copies of the 518 GB file (prefill split 10:5 / 10:5:5, decode 10:6 / 10:6:6). Steady excludes the first decode step; inclusive includes it; both exclude startup and prefill. Upstream is the median of 6 arms and each fork rung the median of two: observed ranges, not confidence intervals. The upstream control is the base commit this fork is pinned to, built with the same Apple clang 14.0.3 / macOS 26.4 SDK toolchain; it is not current upstream ds4, and nothing here is broad model-quality or chat/server validation.

Fork arms ran with 4,600 cached experts, the flag readback, fused BF16 epilogues and the pipeline cache (the published stack profile). Upstream ran with its automatic cache budget (3,688 experts). Gates on every arm: reference output hash, requested cache honoured, zero swap growth; fork arms additionally at least 1,600 MHz active GPU clock from an independent `powermetrics` collector (upstream has no keep-alive and idles between reads, so its active-weighted clock is recorded, not gated). No build ran and no second engine process existed during any arm.

## All arms in run order

| # | Arm | Rung | Prompt processing | Incl. first step | Steady | First step ms | GPU MHz | Swap MB | Output SHA-256 |
|---:|---|---|---:|---:|---:|---:|---:|---:|---|
| 1 | ladder-0927-1U | upstream ds4 bd66c40, internal SSD only | 17.76 | 9.92 | 10.20 | 645 | 1523 | 0 | 8182ab832dcc… |
| 2 | ladder-0927-2S1 | this fork, internal SSD only (no replicas) | 31.10 | 17.36 | 18.59 | 812 | 1620 | 0 | 8182ab832dcc… |
| 3 | ladder-0927-3U | upstream ds4 bd66c40, internal SSD only | 17.91 | 9.77 | 10.06 | 675 | 1491 | 0 | 8182ab832dcc… |
| 4 | ladder-0927-4S2 | this fork, internal + one enclosure | 36.89 | 19.52 | 21.04 | 784 | 1620 | 0 | 8182ab832dcc… |
| 5 | ladder-0927-5U | upstream ds4 bd66c40, internal SSD only | 18.00 | 9.94 | 10.22 | 647 | 1522 | 0 | 8182ab832dcc… |
| 6 | ladder-0927-6S3 | this fork, internal + two enclosures | 41.23 | 20.47 | 22.15 | 782 | 1620 | 0 | 8182ab832dcc… |
| 7 | ladder-0927-7S3 | this fork, internal + two enclosures | 43.60 | 21.02 | 22.35 | 607 | 1620 | 0 | 8182ab832dcc… |
| 8 | ladder-0927-8U | upstream ds4 bd66c40, internal SSD only | 18.09 | 9.82 | 10.11 | 661 | 1524 | 0 | 8182ab832dcc… |
| 9 | ladder-0927-9S2 | this fork, internal + one enclosure | 36.87 | 19.56 | 21.07 | 777 | 1620 | 0 | 8182ab832dcc… |
| 10 | ladder-0927-10U | upstream ds4 bd66c40, internal SSD only | 17.93 | 9.88 | 10.15 | 635 | 1527 | 0 | 8182ab832dcc… |
| 11 | ladder-0927-11S1 | this fork, internal SSD only (no replicas) | 30.87 | 17.54 | 18.74 | 786 | 1620 | 0 | 8182ab832dcc… |
| 12 | ladder-0927-12U | upstream ds4 bd66c40, internal SSD only | 18.04 | 9.96 | 10.24 | 640 | 1530 | 0 | 8182ab832dcc… |

[Timing CSVs](arms/) · [Measured results](results.json) · [Verifier](verify-results.py)

## Reproduce

Build the fork from tag `v41-stack-20260927` and the control with `python3 argodrive/reproduce/build.py --variant upstream --checkout /path/to/upstream` (same toolchain). Run `argodrive/reproduce/run.py run --variant upstream` for the control and `--variant fork --profile v41-stack-20260927` for the fork; for the internal-only and one-enclosure rungs the published profile currently requires two replicas, so pass the profile's environment with `--ssd-streaming-cache-experts 4600` and zero or one `--replica` (decode weights `10,6` for one enclosure). Interleave the rungs, use a new output directory per arm, and retain failed attempts.

Built on [ds4 by antirez and contributors](https://github.com/antirez/ds4). [Credits](../../../CREDITS.md) · [Argodrive](https://github.com/argonautlabsai/argodrive).
