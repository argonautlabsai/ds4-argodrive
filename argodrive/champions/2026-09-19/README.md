# DeepSeek V4.1 three-drive champion checkpoint

Saved on September 20 as `champion-v41-20260919`. The engine and Metal shaders
are unchanged from `05026146efce4aedff191c052078f4d2ff040117`; the checkpoint adds
the explicit reproduction profile, allocation/sampler guards, and this record.

The recorded September 19 result is **18.45 steady tokens/s** at **512 prompt
tokens / 200 generated tokens**, on an M5 Max with 128 GiB and three SSDs.
Steady speed excludes the first decode step. The four-pair qualification
reported 17.84 → 18.45 steady tokens/s, with all four pairs positive and identical
generated output. This saves that historical champion; it does not promote the
September 20 experiments or claim a new run today.

## What is preserved

- [Profile and historical summary](profile.json): full model identity, prompt
  hash, cache size, weights and environment settings.
- [Engine source checksums](engine-source-sha256.json): engine, headers, build
  file and runtime Metal sources from the qualified code revision.
- [Retained pair](retained-pair.json) and its original benchmark CSVs: control
  **17.77 steady / 17.29 inclusive**, champion **18.46 steady / 17.89 inclusive**.
  Both retained the full 4,200-expert cache and the same generated-text SHA-256.

The aggregate four-pair result is preserved from the existing revision's README.
The two CSVs here are the retained final pair, not all eight original arms; do
not recompute the four-pair median from them. An inclusive four-pair median is
not available in this checkpoint. First decode-step timing is not client TTFT.
Output equality on this prompt does not establish broad model quality.

## Settings

| Item | Champion |
|---|---|
| Expert files | Full identical GGUF replicas on internal + two external SSDs |
| Prefill split | 10:5:5 |
| Decode split | 10:6:6 |
| Reader limit | 9 |
| Expert cache | 4,200 experts, locked allocation required |
| Prefill | Selective staging, one-layer read-ahead, 8 staging lanes |
| Decode overlap | Resident gate/up work while missing experts load |
| Engram | Primary SSD, 8 asynchronous whole-row readers |
| GPU keepalive | Read-wait scope, 8 threadgroups, 300,000 iterations |
| CPU keepalive | One busy thread |
| Speculative decoding | Off |

Keepalive increases power use. The September 20 tests also found performance
sensitive to sleep, GPU clocks and background graphics activity. Do not equate
a selected High Power setting with measured clock stability.

## Restore and build

```sh
git clone --branch champion-v41-20260919 https://github.com/argonautlabsai/ds4-argodrive.git
cd ds4-argodrive
# Record the compiler and SDK before building.
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
xcrun clang --version
make -j4 CC="$(xcrun --find clang)" ds4 ds4-bench ds4-server
python3 -m unittest discover -s argodrive/reproduce/tests -p 'test_*.py'
```

The archived champion objects identify Apple clang 14.0.3. The September 20
matching-output rebuild used that compiler with the installed macOS 26.4 CLT
SDK. Xcode clang 21 / SDK 27.0 changed greedy output in a separate rebuild;
record and match the actual toolchain, not just the directory name. Build from
a clean checkout and keep runtime shaders beside the executable. Model weights
and prebuilt binaries are not included.

## Verify and run

Replace these three example paths with your own copies. Verification reads each
518.6 GB file fully once; the receipt is local and must not be shared publicly.

```sh
python3 argodrive/reproduce/verify.py \
  --model /path/to/internal/DeepSeek-V4.1-Flash-Q4.gguf \
  --replica /path/to/enclosure-1/DeepSeek-V4.1-Flash-Q4.gguf \
  --replica /path/to/enclosure-2/DeepSeek-V4.1-Flash-Q4.gguf \
  --out /path/to/new-receipt.json

python3 argodrive/reproduce/run.py run \
  --variant fork --profile champion-20260919 \
  --engine "$PWD/ds4-bench" \
  --model /path/to/internal/DeepSeek-V4.1-Flash-Q4.gguf \
  --replica /path/to/enclosure-1/DeepSeek-V4.1-Flash-Q4.gguf \
  --replica /path/to/enclosure-2/DeepSeek-V4.1-Flash-Q4.gguf \
  --receipt /path/to/new-receipt.json \
  --prompt "$PWD/speed-bench/promessi_sposi.txt" \
  --prompt-tokens 512 --tokens 200 --out /path/to/new-champion-arm
```

Replace `run` with `plan` to inspect the settings without starting inference.
The harness checks distinct physical SSDs and verified replica identities,
clears inherited model environment variables, and refuses reduced cache
allocations or excessive swap growth. A selected physical sampler must produce
baseline counters for every drive before inference starts. See the
[sampler recipe](../../reproduce/README.md#optional-physical-device-evidence).

New comparisons need matched runs, full cache allocation, output checks and
stable machine state. Save inclusive and steady decode rates separately.
Local run folders contain file paths and device identities; use a reviewed
summary for publication rather than uploading them wholesale.

Built on [antirez/ds4](https://github.com/antirez/ds4), with the project's
[credits and AI-assistance disclosure](../../../CREDITS.md) preserved.
