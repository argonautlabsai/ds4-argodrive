# Drive ladder with the 4 October prefill profile

Pinned upstream ds4 against profile `v41-stack-20261004` on one, two and three drives, one interleaved session
(order U, S1, U, S2, U, S3, S3, U, S2, U, S1, U), 512-token prompt, 200 generated, output identical on all 12 arms.

| | prompt processing tok/s | steady decode tok/s | incl. first step tok/s |
|---|---:|---:|---:|
| upstream ds4 `bd66c40`, internal SSD only, automatic cache | 17.30 | 10.17 | 9.80 |
| this fork, internal SSD only, no replicas | **47.71** (2.76×) | 16.94 (1.67×) | 16.29 (1.66×) |
| this fork, + one enclosure (10:5 prefill, 10:6 decode) | 62.99 (3.64×) | 18.64 (1.83×) | 17.83 (1.82×) |
| this fork, + two enclosures (10:5:5 prefill, 10:6:6 decode) | **75.06** (4.34×) | 19.31 (1.90×) | 18.56 (1.89×) |

Upstream is the median of 6 arms, each fork rung the median of 2. Multipliers are against the upstream
median of the same session. The internal-only row is software only: same laptop, same single SSD, same model file,
no replicas. The profile adds, to the 30 September read-ahead staging, a continuous prefill reader, Engram row-table
reads on upstream's prefetch thread from the first layer, and a conditional read-ahead prior ([how it works and the
qualification](../2026-10-04-engram/README.md)).

**Conditions to read before quoting.** Fork rungs ran with a 3,600-expert cache, not the champion's 4,600: the larger
cache tripped the swap-growth guard on a machine with twenty days of uptime and 4 GB of swap in use, and this session
was run without a reboot at KP's request. Decode rungs are therefore below the [27 September ladder](../2026-09-27-ladder/README.md)
(18.66 / 21.05 / 22.25 at 4,600), and that ladder remains the decode reference. The campaign accepted swap growth of
at most 64 MB per arm instead of zero; the largest observed was 0.0 MB, and every value is in `results.json`.
GPU clocks held 1,620 MHz on every fork arm. Every arm ran as a fresh process with an empty expert cache.

[All 12 timing CSVs](arms/) · [Machine-readable results](results.json) · `python3 verify-results.py`
