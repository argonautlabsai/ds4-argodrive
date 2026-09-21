# V4.1 router profile

`v41-router-20260921` extends the pinned September 21 three-drive champion
with a V4.1 router fast path and a small fusion stack. Select it explicitly;
the existing profiles and engine defaults are unchanged.

The [matched results and all attempts](../candidates/2026-09-21-router/README.md)
record 20.105 steady / 19.445 inclusive tok/s at pp512/tg200. The longer repeat
has not qualified because GPU clocks varied between arms.

The engine source revision is `a53dab7bdd435b41974371a393e7eb883fa9774b`.
The profile adds exactly these settings:

```sh
DS4_ARGODRIVE_HC_EXPAND_BF16=1
DS4_ARGODRIVE_ROPE_INPUT=1
DS4_ARGODRIVE_QAKV_BF16=1
DS4_ARGODRIVE_Q8_ROWS_EPILOGUE=1
DS4_ARGODRIVE_VIEW_CACHE=1
DS4_ARGODRIVE_V41_ROUTER_FUSION=4
```

The router specializes the single-token, 384-expert, top-six path. It preserves
the original 512-wide padded bitonic selection network, comparison and tie
rules, and the separate six-thread weight reduction. Within-SIMD exchanges
use shuffles; cross-SIMD stages use alternating threadgroup buffers. Probability
and weight transformations retain the reference floating-point materialization
boundaries. Other shapes and disabled/invalid modes use the original path.
Hash routing, quality mode and mixed visual routing are excluded from this
optimization.

The HC expansion combines an existing operation with its BF16 rounding step.
The other enabled fusions already existed as optional switches. No quantization,
model weights, expert selection policy or precision setting changes.

## Run

Build with the same compiler and SDK as the comparison, using the
[champion build instructions](../champions/2026-09-21/README.md#build-and-reproduce).
Use the same model, replicas, receipt and command, replacing only
`--profile champion-20260921` with `--profile v41-router-20260921`:

```sh
python3 argodrive/reproduce/run.py run \
  --variant fork --profile v41-router-20260921 \
  --engine "$PWD/ds4-bench" \
  --model /path/to/internal/DeepSeek-V4.1-Flash-Q4.gguf \
  --replica /path/to/enclosure-1/DeepSeek-V4.1-Flash-Q4.gguf \
  --replica /path/to/enclosure-2/DeepSeek-V4.1-Flash-Q4.gguf \
  --receipt /path/to/your-receipt.json \
  --prompt "$PWD/speed-bench/promessi_sposi.txt" \
  --prompt-tokens 512 --tokens 200 --accounting --timeline \
  --sampler /path/to/argodrive-phase-sampler --out /path/to/new-arm
```

The inherited setup is 4,200 cached experts, nine persistent read threads,
prefill split 10:5:5, decode split 10:6:6 and 32-token cache decay. Engram remains
on the internal drive with eight asynchronous readers. Keepalive remains enabled
and increases power use. Use `plan` to review the command without inference.

Use a separate build of `champion-v41-20260921` as the control. Compare the same
prompt, generated length, cache allocation, sampling and power conditions.
Report steady and generation-inclusive rates separately. Matched generated text
is a regression check, not broad model-quality validation.

## Regression fixtures

```sh
python3 -m unittest discover -s argodrive/reproduce/tests -p 'test_*.py'
python3 argodrive/reproduce/test-champion.py
make test-deepseek41-metal test-metal-command-memory
```

The router fixture exercises all four modes with exact output comparison,
including ties, padding, biased scores, scaling, extreme inputs, buffer-view
offsets, fallback dimensions and output canaries. The public profile has a
separate test that proves its exported environment is the previous champion
plus exactly the six settings above.

Cache decay 64/128 and Q8 row tiling 4/8 were screened and rejected. They are
not part of this profile. First-decode-step latency remains a separate target;
moving work before a timer would not establish a reduction in end-to-end wait.
