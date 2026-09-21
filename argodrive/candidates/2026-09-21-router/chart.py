"""Render only the qualified pp512/tg200 group, with both decode metrics."""
import json
import statistics
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root = Path(__file__).resolve().parent
data = json.loads((root / 'results.json').read_text())
arms = [a for a in data['arms'] if a['group'] == 'final200']
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10, 'svg.fonttype': 'none'})
fig, axes = plt.subplots(1, 2, figsize=(10.8, 4.6), sharey=True)
for ax, field, title in zip(axes, ['steady_tok_s', 'generation_tok_s'],
                           ['Steady decode', 'Including first decode step']):
    for x, label in enumerate('AB'):
        values = [a[field] for a in arms if a['label'] == label]
        value = statistics.median(values)
        ax.bar(x, value, width=.58, color=['#536477', '#087e75'][x])
        ax.plot([x-.06, x+.06], values, 'o', color='#182330', ms=4, zorder=3)
        ax.text(x, value+.55, f'{value:.3f}', ha='center', fontweight='bold', fontsize=12)
    ax.set_title(title, loc='left', fontweight='bold', pad=14)
    ax.set_xticks([0, 1], ['Published champion\nmatched rerun', 'Router candidate'])
    ax.set_ylim(0, 22.5)
    ax.set_axisbelow(True)
    ax.yaxis.grid(True, color='#e5e9ed')
    for side in ['top', 'right', 'left']:
        ax.spines[side].set_visible(False)
    ax.spines['bottom'].set_color('#c6cfd7')
    ax.tick_params(axis='both', length=0, pad=8)
axes[0].set_ylabel('tokens / second')
fig.suptitle('DeepSeek V4.1 router candidate · three SSDs', x=.065, ha='left', fontsize=17, fontweight='bold', y=.99)
fig.text(.065, .91, 'M5 Max · 128 GiB · 512 prompt / 200 generated · ABBA, two runs per configuration', color='#536477')
fig.text(.065, .035, 'Both metrics exclude startup and prefill. Longer-run qualification remains pending.', color='#536477', fontsize=10)
fig.subplots_adjust(top=.77, bottom=.20, left=.065, right=.98, wspace=.18)
fig.savefig(root / 'comparison.svg', metadata={'Date': None, 'Creator': 'Argonaut Labs'})
fig.savefig(root / 'comparison.png', dpi=180, metadata={'Software': 'Argonaut Labs'})
svg = root / 'comparison.svg'
svg.write_text('\n'.join(line.rstrip() for line in svg.read_text().splitlines()) + '\n')
