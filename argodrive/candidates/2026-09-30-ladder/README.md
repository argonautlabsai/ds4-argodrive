# Drive ladder with the prefill profile — September 30

Pinned upstream ds4 against profile `v41-stack-20260930` on one, two and three drives, one interleaved session
(order U, S1, U, S2, U, S3, S3, U, S2, U, S1, U), 512-token prompt, 200 generated, output identical on all 12 arms.

| | prompt processing tok/s | steady decode tok/s | incl. first step tok/s |
|---|---:|---:|---:|
| upstream ds4 `bd66c40`, internal SSD only, automatic cache | 16.12 | 10.11 | 9.73 |
| this fork, internal SSD only, no replicas | **43.75** (2.71×) | 16.77 (1.66×) | 16.15 (1.66×) |
| this fork, + one enclosure (10:5 prefill, 10:6 decode) | 58.13 (3.61×) | 18.67 (1.85×) | 17.89 (1.84×) |
| this fork, + two enclosures (10:5:5 prefill, 10:6:6 decode) | **68.29** (4.24×) | 20.02 (1.98×) | 19.22 (1.98×) |

Upstream is the median of 6 arms, each fork rung the median of 2. Multipliers are against the upstream
median of the same session. The internal-only row is software only: same laptop, same single SSD, same model file,
no replicas. Prompt processing is the new result: read-ahead staging fetches the next layer's likeliest experts while
the GPU computes the current one, and the routed MoE runs in two waves around the remaining reads ([how it works and
the qualification](../2026-09-30-prefill/README.md)).

**Conditions to read before quoting.** Fork rungs ran with a 3,600-expert cache, not the champion's 4,600: the larger
cache tripped the swap-growth guard on a machine with fifteen days of uptime and 8 GB of swap in use, and this
session was run without a reboot at KP's request. Decode rungs are therefore below the [27 September ladder](../2026-09-27-ladder/README.md)
(18.66 / 21.05 / 22.25 at 4,600), and that ladder remains the decode reference. The campaign accepted swap growth of
at most 64 MB per arm instead of zero; the largest observed was 0.0 MB, and every value is in `results.json`.
GPU clocks held 1,620 MHz on every fork arm. Every arm ran as a fresh process with an empty expert cache.

[All 12 timing CSVs](arms/) · [Machine-readable results](results.json) · `python3 verify-results.py`
