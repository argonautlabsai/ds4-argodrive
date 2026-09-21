# V4.1 router candidate — September 21

**20.105 steady tok/s at pp512/tg200**, measured on an M5 Max with 128 GiB,
internal SSD and two Thunderbolt 5 NVMe enclosures. The generation-inclusive
median is **19.445 tok/s**. This candidate passed the 200-token matched repeat;
**512-token and alternate-prompt performance qualification remain pending**.

![Matched 200-token steady and inclusive results](comparison.svg)

| Metric | Published champion, rerun | Router candidate | Change |
|---|---:|---:|---:|
| Steady tok/s, median | 19.665 | **20.105** | **+2.24%** |
| Steady tok/s, range | 19.64–19.69 | 20.06–20.15 | |
| Generation-inclusive tok/s, median | 19.075 | **19.445** | **+1.94%** |
| First decode step, median | 360.968 ms | 384.384 ms | +6.49% time |
| Prompt processing, median | 45.185 tok/s | 44.900 tok/s | −0.63% speed |

Four runs in ABBA order, two per configuration. All use the same 512-token raw
completion prompt, 200 generated tokens, 4,096 context allocation and 4,200
cached experts. Output SHA-256, cache misses and allocation matched; swap growth
was zero and measured decode GPU frequency was 1,620 MHz on every run.

Steady excludes the first decode step; inclusive includes it. Both exclude
startup and prefill. The first token is produced by prefill; the first decode
step is a separate operation. Two repeats give an observed range, not a
confidence interval. This comparison reruns our published champion, **not
upstream ds4**. It does not establish a universal hardware record or broad
model-quality validation.

## Implementation and profile

The implementation is included in the repository. Source revision
`a53dab7bdd435b41974371a393e7eb883fa9774b` adds a specialized 384-expert/top-six
router with SIMD selection. It preserves the padded reference sorting network,
tie behavior and floating-point materialization boundaries while reducing
dispatches and threadgroup synchronization. A small fusion stack combines HC
expansion/BF16 rounding, RoPE input, QAKV, Q8 row epilogues and view caching.

The [profile](profile.json) is `v41-router-20260921`. It keeps prefill weights
10:5:5, decode weights 10:6:6, nine persistent readers, 4,200 cached experts and
32-token cache decay. Engram stays on the internal SSD with eight asynchronous
readers. Keepalive remains enabled, consumes additional power and is workload
dependent. Existing profiles and engine defaults are unchanged.

Cache decay 64/128 and Q8 row tiling 4/8 lost speed in matched screens and are
excluded. First-decode-step overhead remains open. No quantization, model file,
requested length or benchmark timer boundary was changed.

## All attempts are retained

[Fourteen timing CSVs](arms/) · [Measured results and byte accounting](results.json)
· [75 source checksums](source-sha256.json) · [Validation](validation.json)

| Group | Order | Steady tok/s in order | Decode GPU MHz in order | Qualification |
|---|---|---|---|---|
| 200-token main prompt | ABBA | 19.64 / 20.15 / 20.06 / 19.69 | 1620 / 1620 / 1620 / 1620 | passed |
| First 512-token group | BAAB | 20.40 / 15.52 / 15.94 / 16.69 | 1620 / 916 / 961 / 985 | clock gate failed |
| Repeated 512-token group | BAAB | 20.43 / 19.82 / 19.92 / 16.35 | 1620 / 1620 / 1620 / 951 | clock gate failed |
| Alternate prompt, 200 tokens | AB | 15.89 / 14.59 | 1620 / 1123 | clock gate failed |

A is the published `champion-v41-20260921` binary/profile; B is this candidate.
The clock gate requires at least 1,600 MHz and no more than 1% variation between
arms. The repeat-range gate is 2%. The first failed 512-token group triggered a
repeat with an automatic clock guard; the guard stopped after the last arm's
clock failure. Both entire 512-token groups and the alternate group are excluded
from speed-gain claims. Their faster individual runs are not promoted.

Clock drops occurred on both configurations; their cause is unestablished.
No power setting changed between these runs. The matched output, full cache,
zero swap growth and exact expert application-counter closure checks passed on
all fourteen arms. Physical read counters cover all three SSDs during prefill
and decode. Their residual against instrumented application bytes is unassigned:
other I/O and 100 ms boundary uncertainty remain. Engine first-token markers
are recorded separately and are not client-observed TTFT.

The [previous champion](../../champions/2026-09-21/README.md), which passed both
200- and 512-token repeats, remains available under its unchanged tag.

## Build and reproduce

```sh
git clone --branch v41-router-20260921 https://github.com/argonautlabsai/ds4-argodrive.git
cd ds4-argodrive
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
xcrun clang --version
make -j4 CC="$(xcrun --find clang)" ds4 ds4-bench ds4-server
python3 argodrive/candidates/2026-09-21-router/verify-results.py
```

The measured build used **Apple clang 14.0.3 / macOS 26.4 SDK**. Match and verify
the installed toolchain; a directory selection does not install that version.
Keep the executable beside its `metal/` sources. Model files are separate.

Follow the [complete profile command](../../reproduce/V41-ROUTER.md#run), using
three fully verified, identical Q4 GGUF copies and the physical sampler.
Use `--profile v41-router-20260921`. The model is 518,596,067,328 bytes with SHA-256
`a5e2e2c3ada4b2e98d9f9e4b50f6d9c2a12c2c96f5da165c07e13aff9264984e`.
The runner refuses unverified replicas, reduced cache allocations and excessive
swap growth. Use separate output directories and retain failed attempts.

## Validation scope

CLI, benchmark and server builds passed. The 27 Python tests, twelve focused
fusion/reader/cache/keepalive fixtures, dedicated router fixture (84 cases ×
four modes × two buffer-view offsets), core V4.1 Metal fixture, command-memory
fixture and CPU-only compile/link/help check passed. No CPU model inference,
CUDA, distributed hardware or broad quality suite was run. The public profile's
exported settings match the measured candidate exactly. Source hashes match all
75 recorded engine/build/shader files.

The verifier below checks recorded evidence; it does not rerun inference:

```sh
python3 argodrive/candidates/2026-09-21-router/verify-results.py
python3 -m unittest discover -s argodrive/reproduce/tests -p 'test_*.py'
python3 argodrive/reproduce/test-champion.py
```

Built on [ds4 by antirez and contributors](https://github.com/antirez/ds4).
[Credits and AI assistance](../../../CREDITS.md) ·
[Argodrive app and downloads](https://github.com/argonautlabsai/argodrive).
