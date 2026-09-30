# Prefill read-ahead hotlists

`v41-flash-q4-readahead-20260930.txt` ranks, per layer, the routed experts of
DeepSeek V4.1 Flash Q4 by how often they were selected during 512-token prefills of
19 prompts that do not overlap the benchmark prompt: 14 slices of *I Promessi Sposi*
taken from later in the book (the benchmark prompt is its first 512 tokens), four
slices of the English long-context story prompt shipped in `tests/`, and the
alternate benchmark passage in `../prompts/alternate.txt`. Format: one line per
layer, `layer n id:count ...`; the engine re-ranks by count on load.

The list is a performance prior only: it decides which experts the read-ahead
thread fetches first while the GPU computes the previous layer. Routing, weights
and arithmetic are unchanged, and the output is byte-identical with or without it.
A prior built from different text changes speed, not results; a 37-prompt list
that added English technical prose covered 65.6% of the benchmark prompt's
selections at K=180 against 68.9% for this list.

Rebuild from selection dumps (`DS4_ARGODRIVE_PREFILL_IDS_DUMP`) with
`tools/make-hotlist.py` in the working tree; never include the prompt being
measured.
