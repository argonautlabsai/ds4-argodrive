# DS4 Argodrive — DeepSeek V4.1 on three SSDs

**23.260 steady tok/s at 512 generated tokens; 22.755 generation-inclusive tok/s.** DeepSeek V4.1 Flash Q4 (518.6 GB), M5 Max with 128 GiB, internal SSD plus two Thunderbolt 5 NVMe enclosures; 512-token prompt. Measured on 28 September against the published 27 September binary, built from its tag and run in the same session with the same profile and 4,600-expert cache: **+1.48% steady / +1.27% inclusive** at 512 generated tokens (BAAB, two runs per configuration) and **+1.71%** at 200 (ABBA). Same drives and model copies; byte-identical reference outputs on every arm, zero swap growth, GPU clocks held at 1,620 MHz.

![Matched 512-token steady and inclusive results](argodrive/candidates/2026-09-28-flush/comparison.svg)

| Metric, pp512/tg512 | Published 27 September binary, same-session rerun | Profile `v41-stack-20260928` | Gain |
|---|---:|---:|---:|
| Steady tok/s, median | 22.920 | **23.260** | **+1.48%** |
| Including first decode step, median | 22.470 | **22.755** | **+1.27%** |
| Steady tok/s, both runs | 22.88 / 22.96 | **23.18 / 23.34** | pairs +0.30, +0.38 |

A small step on top of the 27 September stack, which carried the large move (+12.0% over the 21 September champion, see below). The two additions are a post-MoE flush, which commits a layer's routed work as soon as it is encoded when that layer waited for expert reads, and an eviction pre-scan that ranks cache victims while the CPU waits on the router mailbox. Neither touches arithmetic or expert selection. Next-layer prediction was re-tested the same day in three forms and lost; the package records why. Both decode metrics exclude startup and prefill; steady also excludes the first decode step. This compares against our previous Argodrive champion, not current upstream ds4, and does not establish broad model quality or chat/server performance.

[**Qualified results release**](https://github.com/argonautlabsai/ds4-argodrive/releases/tag/v41-stack-20260928) · [**Results, all 35 CSVs and the rejected levers**](argodrive/candidates/2026-09-28-flush/README.md) · [**Reproduce the result**](argodrive/reproduce/V41-STACK.md#run) · [**Machine-readable evidence**](argodrive/candidates/2026-09-28-flush/results.json)

**Against pinned upstream ds4 on one, two and three drives** (27 September, one interleaved session, 512-token prompt, 200 generated; upstream median of 6 arms, fork rungs median of two):

| | prompt processing tok/s | steady decode tok/s | incl. first step tok/s |
|---|---:|---:|---:|
| upstream ds4 `bd66c40`, internal SSD only, automatic cache | 17.96 | 10.18 | 9.90 |
| this fork, internal SSD only, no replicas | **30.98** (1.72×) | **18.66** (1.83×) | 17.45 (1.76×) |
| this fork, + one enclosure (10:5 prefill, 10:6 decode) | 36.88 (2.05×) | 21.05 (2.07×) | 19.54 (1.97×) |
| this fork, + two enclosures (10:5:5 prefill, 10:6:6 decode) | **42.41** (2.36×) | **22.25** (2.19×) | 20.74 (2.10×) |

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="argodrive/charts/ladder-dark.svg">
  <img src="argodrive/charts/ladder.svg" alt="Prompt processing and steady decode, pinned upstream vs this fork on one, two and three drives, 27 September 2026">
</picture>

The internal-only row is software only: the same laptop, the same single SSD and the same model file as the upstream control, with no replicas. Output is byte-identical to upstream on all 12 arms. Every arm ran as a fresh process with an empty expert cache; fork arms held 1,620 MHz GPU clocks and zero swap growth. The fork rungs use profile `v41-stack-20260927` with 4,600 cached experts; upstream sizes its cache automatically (3,688). This is the pinned upstream base of this fork, not current upstream ds4. [Ladder results, all 12 CSVs and the verifier](argodrive/candidates/2026-09-27-ladder/README.md) · [machine-readable](argodrive/candidates/2026-09-27-ladder/results.json).

Profile `v41-stack-20260928` is `v41-stack-20260927` plus exactly `DS4_ARGODRIVE_POST_MOE_FLUSH=1` and `DS4_ARGODRIVE_VICTIM_PRESCAN=1`; the earlier profiles remain selectable. Profile `v41-stack-20260927` is the published router profile plus three opt-in engine paths and a 4,600-expert cache (was 4,200). **Flag readback** (+6.6% alone): a mailbox kernel publishes the router's expert ids from inside the running command buffer; the CPU polls it and starts the miss reads while the shared-expert work, encoded before the commit, keeps the GPU busy. **Larger cache** (+3.0 to +3.3% alone): steady misses per token fall from 13.1 to 11.1 at 512 tokens. **Fused BF16 epilogues** (+0.5%) and a **pipeline-state cache** (+0.8%), plus an environment-lookup cache that is now the code default (+0.5%). Each lever was screened with interleaved pairs before the stack was qualified as a whole. Cache sizes above 4,600 tripped the swap guard; memory keep-alives, read-pool spinning, completion polling, Q8 row tiling and pipeline pre-warming were screened and rejected. Engine defaults are unchanged and the earlier profiles still run.

This fork builds on [ds4 by Salvatore Sanfilippo (antirez) and contributors](https://github.com/antirez/ds4). The reader, scheduling changes and Metal kernels are included in this repository; no private provider is required. Original licences, acknowledgements and [credits](CREDITS.md) are preserved. Development and review used Claude, ChatGPT and OpenAI Codex.

Build release tag `v41-stack-20260928` and select profile `v41-stack-20260928`. Prefill reads split **10:5:5**, decode **10:6:6**; Engram stays asynchronous on the primary SSD. Keepalive consumes additional power and can lose performance under competing GPU work.

## Build and test

```sh
git clone --branch v41-stack-20260928 https://github.com/argonautlabsai/ds4-argodrive.git
cd ds4-argodrive
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
xcrun clang --version
make -j4 CC="$(xcrun --find clang)" ds4 ds4-bench ds4-server
python3 argodrive/candidates/2026-09-28-flush/verify-results.py
```

The measured toolchain was Apple clang 14.0.3 / macOS 26.4 SDK. Verify your installed versions and follow the [full profile run command](argodrive/reproduce/V41-STACK.md#run) with three verified model copies. Model files are separate. The [validation record](argodrive/candidates/2026-09-28-flush/validation.json) lists passed checks and untested configurations.

## Inspect your storage with Argodrive

[**Argodrive app and downloads**](https://github.com/argonautlabsai/argodrive) provides live drive charts and saved-run comparison. Use it to inspect storage behavior and compare your measurements; this engine's benchmark recipe is above. Report feedback in the [Argodrive issue tracker](https://github.com/argonautlabsai/argodrive/issues).

<details>
<summary>Earlier benchmark campaigns and reproduction records</summary>

**Previous champion (27 September):** [stack qualification](argodrive/candidates/2026-09-27-stack/README.md), release `v41-stack-20260927`, profile `v41-stack-20260927`: **22.740 steady / 22.325 inclusive tok/s** at pp512/tg512 (+12.02% / +11.40% over the 21 September champion, BAAB, two runs per configuration; runs 22.65 / 22.83 vs 20.26 / 20.34) and 22.490 / 21.500 at pp512/tg200 (+12.65%). Flag readback of the router ids, a 4,600-expert cache, fused BF16 epilogues and a pipeline cache; prefill about 2% slower and the first decode step 452 vs 371 ms. Against the published 21 September medians (20.375 steady / 20.115 inclusive) its medians were +11.6% / +11.0%. Both decode metrics exclude startup and prefill; steady also excludes the first decode step. The gain is software only. It costs about 2% prefill (44.02 against 44.95 tok/s) and about 80 ms on the first decode step, because the larger cache seeds more expert slabs. This compares against our previous Argodrive champion, not current upstream ds4, and does not establish broad model quality or chat/server performance. Three clock-affected arms from the first attempt remain excluded and available alongside the 32 passing arms.

**Previous champion (21 September):** [router profile qualification](argodrive/candidates/2026-09-21-router/README.md), release `v41-router-qualified-20260921`, profile `v41-router-20260921`: **20.375 steady / 20.115 inclusive tok/s** at pp512/tg512 (+2.75% / +2.76% over the 19 September champion, BAAB, two runs per configuration) and 20.105 / 19.445 at pp512/tg200; alternate-prompt check 16.24 / 15.78, one pair. Ten clock-affected attempts are retained and excluded.

**Saved champion:** [September 19 checkpoint — exact settings, evidence and restore command](argodrive/champions/2026-09-19/README.md), tag `champion-v41-20260919`. Recorded median **18.45 steady tok/s** at pp512/tg200. Engine/shader sources are pinned; later experiments are not included.

**DeepSeek V4.1 Flash (518 GB, 4-bit) streamed from SSD on a 128 GB MacBook Pro M5 Max — 512-token prompt, 200 generated, output SHA-256 identical to upstream on every arm:**

| | prompt processing tok/s | steady decode tok/s |
|---|---:|---:|
| upstream ds4, internal SSD only | 16.23 | 10.59 |
| this fork, internal SSD only | **28.04** (1.73×) | **14.38** (1.36×) |
| this fork, + one external NVMe | 36.88 (2.27×) | 16.05 (1.52×) |
| this fork, + two external NVMe | **43.62** (2.69×) | **17.38** (1.64×) |
| this fork, + two external NVMe, GPU keep-alive (2026-09-17) | 44.28 (2.73×) | **18.06** (1.71×) |
| this fork, + two external NVMe, GPU keep-alive, decode split 10:6:6 + CPU keep-alive (2026-09-19, default in the profile) | 45.34 (2.79×) | **18.45** (1.74×) |
| this fork, + two external NVMe, 2026-09-27 stack: flag readback, 4,600-expert cache, fused BF16 epilogues (profile `v41-stack-20260927`) | 44.25 (2.73×) | **22.49** (2.12×) |

The ladder chart at the top of this README now shows the 27 September session; the table above keeps the earlier rungs, whose multipliers chain to the 15 September upstream control.

The keep-alive row: `DS4_ARGODRIVE_GAP_KEEPALIVE=1` with `DS4_TP_KEEPALIVE_TGS=8` (commit 361289f) runs a tiny ALU kernel on a second queue only while the CPU waits for expert reads, because the GPU otherwise drops into low-power states during those waits and every kernel after them runs slower. Four interleaved pairs at 512/200, all positive (+0.31, +0.65, +0.84, +0.54 tok/s), medians 17.34 → 17.93; a shorter spin (`DS4_TP_KEEPALIVE_ITERS=300000`, so the kernel stops sooner when a read lands) adds another four positive pairs, 17.80 → 18.06, output identical. Continuous spinning gains nothing.

The 2026-09-19 row adds two knobs found with `powermetrics`. `DS4_ARGODRIVE_DECODE_WEIGHTS=10,6,6` (commit 743616f) gives decode its own split across the three drives while prefill keeps 10:5:5: at 10:5:5 the internal SSD was the last drive to land on two thirds of the decode reads, at 10:6:6 on four tenths, and 10:7:7 overshoots. `DS4_ARGODRIVE_CPU_KEEPALIVE=1` (commit d04ca6a) starts one busy thread at user-interactive QoS when decode begins: the engine's threads spend most of each token waiting, the performance cores sit at their 1344 MHz floor, and the one thread that does the per-layer bookkeeping ran at 3.4 GHz; with a busy neighbour its cluster holds 4.2 GHz. The stack against the 09-17 champion, four interleaved pairs at 512/200: +0.53, +0.56, +0.62, +0.69 tok/s, medians 17.84 → 18.45, output SHA identical on all eight arms, prefill unchanged, about 4.5 W more CPU power. The champion configuration measured 17.8-17.9 that night against 18.06 two days earlier, inside the ±2% floor of this workload.

The single-drive row needs no extra hardware: commit 38e200a lets the selective prefill path run on one source. Details, method and raw arms: [argonautlabs.ai/research](https://argonautlabs.ai/research/deepseek-2026-09-15.html) · tooling: [ArgoDrive](https://github.com/argonautlabsai/argodrive).


Built on [ds4 by Salvatore Sanfilippo (antirez) and contributors](https://github.com/antirez/ds4), with experimental streaming changes and [ARGODRIVE tooling](https://github.com/argonautlabsai/argodrive). Original licences and upstream acknowledgements are preserved; see [credits](CREDITS.md).

This branch includes the actual expert replica reader and Metal scheduling changes used by the V4.1 benchmarks. No separate provider library is required. It is pinned to upstream `bd66c402070042bf0a79ad6ece8242de4c93680c`. The earlier `argonaut-v41` branch contains a different GLM integration and is not this benchmark engine.

## Try Argodrive on your Mac

[**Download the Apple-silicon beta**](https://github.com/argonautlabsai/argodrive/releases/tag/v0.2.0-beta.3) · [**Testing guide**](https://github.com/argonautlabsai/argodrive/blob/beta-20260914/docs/BETA-TESTING.md) · [**Argodrive GitHub**](https://github.com/argonautlabsai/argodrive)

The beta provides live drive charts and saved-run comparison. Install it, open Live Hardware, and choose a folder containing supported benchmark runs to inspect and compare them. Engine benchmarks use the recipe below; the app is not a one-click speed optimizer. The beta is ad-hoc signed and not notarized; model files are separate. [Report testing feedback](https://github.com/argonautlabsai/argodrive/issues).

## Build and reproduce

```sh
git clone --branch argonaut-v41-benchmark https://github.com/argonautlabsai/ds4-argodrive.git
cd ds4-argodrive
# For the September 19 champion, match its recorded CLT compiler.
# See the checkpoint above; the older September 14 matrix used Xcode.
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
xcrun clang --version
make -j4 CC="$(xcrun --find clang)" ds4 ds4-bench ds4-server
```

Follow [the complete recipe](argodrive/reproduce/README.md) to verify model copies and run internal-only, one-enclosure and two-enclosure configurations. The recipe includes a pinned upstream control, physical disk sampler, output comparison and sanitizer fixtures. Model files are not included.

The reader is implemented in `argodrive_read.h`: complete identical GGUF replicas, 256 KiB block splitting (champion: prefill 10:5:5, decode 10:6:6; legacy profile: 2:1:1), concurrent reads into disjoint buffer spans, and a completion barrier that rejects partial buffers. Scheduling changes live in `ds4.c`, `ds4_metal.m`, and `metal/moe.metal`. Engram uses eight parallel whole-row readers on the primary SSD. This branch does not implement Engram striping, a learned placement policy, or the GLM expected-completion balancer.

## Benchmark results

**14.11 tok/s with internal storage and two SSD enclosures — 40.1% faster than upstream ds4 on internal storage.**

![DeepSeek V4.1 Flash Q4: final matched generation speeds and observed ranges](argodrive/results/charts/v41-final-matched.png)

| Configuration | Median tok/s | Measured range | Gain vs upstream |
|---|---:|---:|---:|
| Upstream ds4 — internal | 10.07 | 10.01–10.12 | Baseline |
| Our fork — internal | 12.32 | 12.28–12.36 | +22.4% |
| Our fork — internal + one enclosure | 13.46 | 13.14–13.65 | +33.7% |
| Our fork — internal + two enclosures | 14.11 | 14.04–14.17 | +40.1% |

Measured on an **M5 Max, 128 GiB, DeepSeek V4.1 Flash Q4**, using the same **512-token prompt and 512 generated tokens**. Rates include the first decode step and exclude prefill and startup. Two runs per configuration, plus a third one-enclosure check; all nine outputs were byte-identical, with no swap growth. Dashboard collection was off. Expert reads use the configured SSD replicas; Engram stays on internal storage.

[**Test details and reproduction**](argodrive/results/FINAL-MATCHED-2026-09-14.md) · [**Measured data**](argodrive/results/final-matched-2026-09-14.json) · [Chart source](argodrive/results/charts/generate-final.py)

---

</details>

## Upstream ds4 documentation (preserved)

<p align="center">
  <img src="logo.svg" alt="DwarfStar logo" width="220">
</p>

**DwarfStar** aims to be the best way to run a few excellent large
language models on consumer hardware (that is, hardware that people
can actually own). To reach this goal, we are building
a small native inference engine optimized first for
**DeepSeek V4 Flash** (including the experimental vision model),
**DeepSeek V4.1 Flash** (Metal only),
and additionally **GLM 5.2 and 5.3**, **GLM 5.3 Flash** and
**DeepSeek V4 PRO**. The code is self-contained and
deliberately narrow, not a general GGUF runner: you need to use the
GGUF files the project produces, that are part of the project
itself.

We test things in integration: model loading, prompt rendering,
tool calls, KV state, the HTTP server, and the coding agent are built and tested together.
The repository also includes tools and data for GGUF, imatrix, quality, and speed.

## Supported hardware

* **Metal**, the primary target, on Macs with 96 GB or more. Smaller machines
  can use SSD streaming. SSD streaming is also needed in order to run very
  large models such as full GLM 5.x (not Flash) on 128GB systems.
* **NVIDIA CUDA**, the DGX Spark is our main gaol. DwarfStar also supports multi-GPU systems that are not supported by other backends, for instance it can run DeepSeek v4 Flash on Ada Lovelace cards.
* **ROCm** on Strix Halo systems such as the Framework Desktop.

This project would not exist without **llama.cpp and GGML**, make sure to read
the acknowledgements section, a big thank you to Georgi Gerganov and all the
other contributors.

**Model support is intentionally opportunistic**. The project follows the best open
weights for useful local machine sizes, especially 128 GB laptops and 256/512 GB
workstations. A model may be removed when a better replacement arrives.

# So, what can I do with this software?

* You can run a very capable models in your consumer hardware, a MacBook, a DGX Spark, or a Strix Halo for example. Even if you have not enough RAM, with SSD streaming, you can run it at a decent speed.
* You can use multiple CUDA cards as a multi-user LLM server. Ada Lovelace, including L40S, is supported: newer models can run here even when their other inference implementations require newer GPUs. Our eight-L40S Flash setup has reached about 126 t/s aggregate generation with 16 sessions.
* Using two 128 GB Macs connected with RDMA, you can run 4-bit DeepSeek Flash or GLM 5.3 Flash with tensor parallelism. Larger GLM 5.2 quants need larger machines, such as Mac Studios.
* You can also use pipeline paralellism to glue together multiple systems to sum their RAM and run larger models.

## Motivations

* Capable open-weight models now fit on high-end personal machines.
* DeepSeek V4 Flash and PRO, GLM 5.2, tolerate aggressive routed-expert quantization.
* Compressed KV caches and fast local SSDs make long contexts practical.
* The idea of an inference system specialized for a few models.

# AI full disclosure

* This software is developed with **strong assistance from AI coding agents** and with humans leading the ideas, testing, and debugging. We say this openly because it shaped how the project was built. If you are not happy with AI-developed code, this software is not for you. The acknowledgement below is equally important: this would not exist without `llama.cpp` and GGML, largely written by hand.

## Acknowledgements to llama.cpp and GGML

`ds4.c` does not link against GGML, but it **exists thanks to the path opened by the
llama.cpp project and the kernels, quantization formats, GGUF ecosystem, and hard-won
engineering knowledge developed there**.
We are thankful and indebted to [`llama.cpp`](https://github.com/ggml-org/llama.cpp)
and its contributors. Their implementation, kernels, tests, and design choices were
an essential reference while building this DeepSeek V4 specific inference path.
Some source-level pieces are retained or adapted here under the MIT license: GGUF
quant layouts and tables, CPU quant/dot logic, and certain kernels. For this
reason, and because we are genuinely grateful, we keep the GGML authors copyright
notice in our `LICENSE` file.

## Status

The software is currently very fast changing. Consider it beta quality.
Before each release, a big QA run is executed, however instabilities
and regressions are definitely possible.

# How to use this project?

I (Salvatore) believe that the way projects should be shipped and used changed because of AI. The main differences today are:

1. With AI, users can modify the software in significant ways with low efforts, costs, and even lacking deep domain knowledge about the task they want to accomplish. For instance, a DwarfStar user with a specific hardware setup can ask a coding agent to improve the inference speed of this software for the specific hardware setup, asking the model to reach the maximum prefill and generation speed without impacting correctness, and also asking to do a deep QA pass.
2. Similiarly, because of "1", software may be shipped in a different way than before. It must be more a working template for the biggest use cases, without trying to cover every possible setup. If DwarfStar showcases a few good implementations of tensor parallel execution, the code will work as a rail for implementing the same feature in specific conditions, for a new model, and so forth.

So, while this project attempts to be usable for the featured models and the most common hardware setups, I ask you, if you have access to coding agents, to consider using coding agents as an interface to discover the project, make modifications, create personalized setups. This way you can likely do more than what we ship, and certain things that are not documented or implemented, and that you require, are potentially very easy to achieve.

## Start Here

```sh
git clone https://github.com/antirez/ds4.git
cd ds4
```

Choose your build. The platform guides cover prerequisites, memory sizing,
and hardware-specific setups:

| Platform guide | Build |
| --- | --- |
| [Metal on Apple Silicon](docs/METAL.md) | `make` |
| [DGX Spark](docs/DGX_SPARK.md) | `make cuda-spark` |
| [Strix Halo / Framework Desktop](docs/STRIX_HALO.md) | `make strix-halo` |
| [One or more CUDA cards, including Ada/L40S](docs/CUDA_MULTI_GPU.md) | `make cuda-generic` |

For a first run on a 96 or 128 GB machine, download DeepSeek V4 Flash Q2:

```sh
./download_model.sh ds4f-q2
```

Downloads go in `gguf/`. Repeat the command to resume an interrupted download.
Leave memory for the context and runtime buffers as well as the model.
See [other models](docs/MODELS.md) or use [SSD streaming](docs/SSD_STREAMING.md)
on a smaller Mac.

## Everyday Use

Once built and with a model downloaded:

```sh
./ds4
./ds4 -p "Explain Redis streams in one paragraph."
./ds4-agent
./ds4-server --ctx 32768
```

The default model is `ds4flash.gguf`, a link updated by main-model downloads.
Pass `-m FILE` to choose explicitly. Commands normally run from the repository
root; use `--chdir /path/to/ds4` when launching elsewhere.

The server listens at `http://127.0.0.1:8000` by default; see [serving](docs/SERVER.md)
for API access and multiple sessions.

The interactive CLI keeps a multi-turn conversation. Use `/help`, `/read FILE`,
`/ctx N`, and `/quit`. Ctrl+C interrupts generation and returns to the prompt.
Run each binary with `--help` for its full options.

### Native coding agent

`ds4-agent` runs inference directly, without a separate HTTP server. It keeps
the token history and live model state together, shows prefill progress, and
uses the model's native tool format. DeepSeek and GLM have their own templates.

Use `/hints on` for occasional, brief explanations of the programming choices
behind the work, and `/hints off` to stop them. Changes take effect at the next
conversation boundary without rebuilding the cached context. New and resumed
sessions start with hints off.

Sessions are stored in `~/.ds4/kvcache`:

| Command | Action |
| --- | --- |
| `/save` | Save the current session |
| `/list` | List saved sessions |
| `/switch <sha>` | Resume a session |
| `/del <sha>` | Delete a saved session |
| `/strip <sha>` | Keep text and title, removing the large KV payload |

Compatible local KV snapshots avoid rebuilding the prompt. Stripped sessions
and network TP restores require prefill. Sessions containing images cannot yet
be saved. Saved conversations and traces may contain private information.

For Pi, OpenCode, Codex CLI, or Claude Code, use `ds4-server` instead and follow
the [client setup guide](docs/CLIENTS.md).

### Models, images, and speculation

[Models and vision](docs/MODELS.md) lists the supported downloads and memory
requirements. DeepSeek Vision Experimental uses a different checkpoint from
Flash 0731; GLM 5.3 Flash adds vision to the same text model.

DeepSeek V4.1 Flash text and vision run on Metal. Q2 runs with SSD streaming
on one 128 GB Mac, or resident across two using RDMA. Q4 needs SSD streaming
or a 512 GB Mac. Engram tables remain on disk in every mode, so use a fast
local SSD. See the [model guide](docs/MODELS.md#deepseek-v41-flash) for downloads
and setup.

With the matching encoder passed as `--vision FILE`, use `/read image.png`
in the CLI or `view_image` in the native agent.

Speculative decoding is opt-in. GLM uses `--mtp`; V4 Flash DSpark needs a matching
support GGUF. It can improve generation, but not every workload benefits.
Read [speculative decoding](docs/SPECULATIVE_DECODING.md) for setup and the
difference between default opportunistic sampling and `--mtp-exact-sampling`.

### Output and power

Thinking is enabled by default. Use `--nothink` or `/nothink` for direct
answers, and `--think` or `/think` to enable it again.
For V4.1, `ds4` and `ds4-agent` also accept
`--think-level 25` or `/think 25`: 1 to 100 sets the reasoning effort, and
0 disables thinking. `--think` selects 75, `--think-max` selects 100.
Changing the level in a conversation rebuilds its cached prefix.
The normal sampling defaults are temperature 1, top-p 1, and min-p 0.05;
`--temp 0` selects greedy output.

For DeepSeek V4, `--power N` trades throughput for lower sustained GPU load.
The default is 100. V4.1 and GLM currently require `--power 100`.

DeepSeek V4 Flash and GLM 5.3 Flash also support directional steering. Load a
vector with `--dir-steering-file FILE`; `/steer F` adjusts its scale for
subsequent tokens in a local CLI or agent session, without rebuilding the
existing KV cache. See [steering documentation](dir-steering/README.md).

`--prefix-file FILE` preloads complete `USER:` / `ASSISTANT:` pairs before
the live conversation. A turn marker must start a line, roles must alternate,
and the last turn must be `ASSISTANT:`.

## Capability Evaluation

`ds4-eval` runs embedded capability regression tests against a real GGUF.
These are DwarfStar integration checks, not official leaderboard scores.

```sh
./ds4-eval -m ds4flash.gguf --trace /tmp/ds4-eval.txt
./ds4-eval -m ds4flash.gguf --suite hard-smoke
./ds4-eval -m ds4flash.gguf --suite hard --retry-incomplete
```

The default suite is `core`; `--suite all` runs core and hard cases.
`--list-cases` lists tests without loading a model. `--plain` selects
non-interactive output, and `--regrade-trace FILE` scores an existing trace
without generating again. Sources and licenses are in [EVAL_DATA.md](EVAL_DATA.md).
For inference correctness and release checks, read [testing](docs/TESTING.md).

## Speed

This recorded DeepSeek V4 Flash Q2 sweep uses an M5 Max with 128 GB RAM,
2048-token continued-prefill intervals, and 128 greedy generation tokens per
frontier. It is a baseline, not a fresh benchmark of every commit.

![M5 Max Flash Q2 throughput](speed-bench/m5_max_ts.svg)

See [performance and benchmarking](docs/PERFORMANCE.md) for the full numbers,
DGX Spark results, comparison conditions, and benchmark commands.

## Detailed Guides

- [Models and vision](docs/MODELS.md): Flash, PRO, GLM, and matching encoders.
- [SSD streaming](docs/SSD_STREAMING.md): run larger than RAM and size the cache.
- [Inference across machines](docs/DISTRIBUTED.md): two-Mac TP/RDMA and layer pipelines.
- [Speculative decoding](docs/SPECULATIVE_DECODING.md): DSpark, GLM MTP, and sampling.
- [Serving](docs/SERVER.md): APIs, images, batching, and disk KV caches.
- [Coding agent clients](docs/CLIENTS.md): Pi, OpenCode, Codex CLI, and Claude Code.
- [Performance](docs/PERFORMANCE.md): reproducible measurements and recorded baselines.
- [Testing and development](docs/TESTING.md): regression tests, debugging, and model-building tools.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before sending a pull request.

## Logo

The DwarfStar logo was designed by hand by Salvatore Sanfilippo, made more
graphical with AI, and manually reworked by Ben Gnomino, whose human touch made
it rock.
