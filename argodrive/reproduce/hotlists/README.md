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

## Conditional prior (4 October)

`v41-flash-q4-cooc-20261004.bin` is a binary table built from per-token routing dumps
(`DS4_ARGODRIVE_PREFILL_TOKENS_DUMP`) of the same 19 prompts: for every pair of consecutive
layers it counts how often each expert of layer L+1 was routed by a token that routed each
expert of layer L (uint16 counts, 39 × 384 × 384), followed by each layer's expert frequencies
(uint32, 40 × 384). Header: `ARCOOC01`, then the layer and expert counts as two uint32s.

With `DS4_ARGODRIVE_COOC=<file>` the engine ranks the next layer's experts for the read-ahead by
`score[e'] = sum_e hits_L[e] * C[L][e][e']`, where `hits_L` are the prompt's own routed counts at
the layer just staged; the frequency breaks ties and the hotlist remains the fallback for layer 0.
On the benchmark prompt the precision of the first 130 experts read ahead rises from 76.7%
(hotlist) to 82.9% (oracle 99.8%). Like the hotlist, it decides read order only: routing,
weights, arithmetic and output are unchanged. A 37-prompt corpus with English technical prose
scored 82.4% and a book-only 24-prompt corpus 83.6%; the shipped table uses the 19-prompt mixed
corpus with the same provenance as the hotlist. Rebuild with `tools/make-cooc.py build` in the
working tree; never include the prompt being measured.
