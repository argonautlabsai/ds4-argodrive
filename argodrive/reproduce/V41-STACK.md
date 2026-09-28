# V4.1 stack profile

## 28 September update: `v41-stack-20260928`

`v41-stack-20260928` is `v41-stack-20260927` plus exactly:

```sh
DS4_ARGODRIVE_POST_MOE_FLUSH=1
DS4_ARGODRIVE_VICTIM_PRESCAN=1
```

The [28 September package](../candidates/2026-09-28-flush/README.md) records 23.260 steady /
22.755 inclusive tok/s at pp512/tg512 (+1.48% / +1.27%) and 22.940 steady at pp512/tg200
(+1.71%) against the `v41-stack-20260927` binary built from its tag, same session, output
byte-identical, together with the same-day levers that lost. The flush commits a layer's routed
MoE right after it is encoded when the layer waited for expert reads; the pre-scan ranks eviction
candidates while the CPU waits on the router mailbox and re-validates each one at use. Run the
command below with `--profile v41-stack-20260928`; everything else on this page applies unchanged.
The drive ladder against upstream was measured with the 27 September profile.


`v41-stack-20260927` extends the published `v41-router-20260921` profile with
three opt-in engine paths and a larger expert cache. Select it explicitly; the
existing profiles and engine defaults are unchanged.

The [matched results and all attempts](../candidates/2026-09-27-stack/README.md)
record 22.740 steady / 22.325 generation-inclusive tok/s at pp512/tg512 and
22.490 / 21.500 at pp512/tg200, each with two runs per configuration against
the published `v41-router-qualified-20260921` binary in the same session
(+12.02% and +12.65% steady). Output is byte-identical to the published
reference outputs on every arm. Use release tag `v41-stack-20260927`.

The engine source revision is `9ad4a610ad1a0c0ac5a10f6036af6f49434bbb5c`.
The profile adds exactly these settings and requests 4,600 cached experts:

```sh
DS4_ARGODRIVE_FLAG_READBACK=1
DS4_ARGODRIVE_BF16_EPILOGUES=1
DS4_ARGODRIVE_PSO_CACHE=1
```

**Flag readback.** After the router kernel, a small kernel inside the same
command buffer writes the selected expert ids, a checksum and a sequence number
into a shared mailbox. The CPU commits the buffer without waiting for it,
polls the mailbox, and as soon as the ids arrive checks the expert cache and
starts the miss reads. The shared-expert work is encoded into the same buffer
before the commit, so the GPU keeps working while the reads start. If the
mailbox has not filled after 50 ms the engine falls back to the original
blocking readback; the qualification arms recorded 8,000 polls and no
fallback. Expert selection, weights and arithmetic are unchanged.

**BF16 epilogues.** Three standalone BF16 rounding passes are folded into the
kernels that produce their inputs, keeping the same round-to-nearest-even
boundary. **Pipeline cache.** A pointer-keyed cache in front of the
pipeline-state lookup. **Environment cache.** Default on in this source; the
engine caches `getenv` results, and `DS4_ARGODRIVE_ENV_CACHE=0` restores the
direct path.

No quantization, model weights, expert selection policy or precision setting
changes. The larger cache costs about 2% prefill and about 80 ms on the first
decode step; the 4,750 and 4,900 sizes exceeded the swap-growth guard on this
128 GiB machine and are not offered.

## Run

Build with the same compiler and SDK as the comparison, using the
[candidate build instructions](../candidates/2026-09-27-stack/README.md#build-and-reproduce).
Use the same model, replicas, receipt and command as the router profile,
replacing only `--profile v41-router-20260921` with `--profile v41-stack-20260927`:

```sh
python3 argodrive/reproduce/run.py run \
  --variant fork --profile v41-stack-20260927 \
  --engine "$PWD/ds4-bench" \
  --model /path/to/internal/DeepSeek-V4.1-Flash-Q4.gguf \
  --replica /path/to/enclosure-1/DeepSeek-V4.1-Flash-Q4.gguf \
  --replica /path/to/enclosure-2/DeepSeek-V4.1-Flash-Q4.gguf \
  --receipt /path/to/your-receipt.json \
  --prompt "$PWD/speed-bench/promessi_sposi.txt" \
  --prompt-tokens 512 --tokens 512 --accounting --timeline \
  --sampler /path/to/argodrive-phase-sampler --out /path/to/new-arm
```

The inherited setup is nine persistent read threads, prefill split 10:5:5,
decode split 10:6:6 and 32-token cache decay. Engram remains on the internal
drive with eight asynchronous readers. Keepalive remains enabled and increases
power use. Use `plan` to review the command without inference.

For the comparison, build the control from `v41-router-qualified-20260921` in a
separate tree and run stack, control, control, stack (BAAB) at 512 generated
tokens and control, stack, stack, control (ABBA) at 200, using a new output
directory for every arm. Record the GPU active clock independently; this
machine occasionally enters a low-clock mode (762 and 907 MHz were observed)
that invalidates a group. Compare the same prompt, generated length, cache
allocation, sampling and power conditions. Report steady and
generation-inclusive rates separately. Matched generated text is a regression
check, not broad model-quality validation.

## Regression fixtures

```sh
python3 -m unittest discover -s argodrive/reproduce/tests -p 'test_*.py'
python3 argodrive/reproduce/test-champion.py
make test-deepseek41-metal test-metal-command-memory
```

The stack profile has a test that proves its exported environment is the
router profile plus exactly the three settings above with 4,600 cached experts.
The new engine paths have no dedicated unit fixture yet; their regression
evidence is byte-identical output on the 35 recorded arms.

Memory keep-alive kernels, read-pool spinning, completion polling, Q8 row
tiling, deferred cache growth, pipeline pre-warming and eighteen reader threads
were screened with interleaved pairs and rejected; the knobs remain in the
source, off by default, and the [session record](../candidates/2026-09-27-stack/README.md)
lists the measurements.
