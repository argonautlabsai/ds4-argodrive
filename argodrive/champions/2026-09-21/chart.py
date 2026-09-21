"""Render the measured steady/inclusive results from the eight public CSVs."""
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root=Path(__file__).resolve().parent
data=json.loads((root/'results.json').read_text())
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'svg.fonttype':'none'})
fig,axes=plt.subplots(1,2,figsize=(10.8,4.2),sharey=True)
colors=['#536477','#087e75']
for ax,key,title in zip(axes,['steady_tok_s','generation_tok_s'],['Steady decode','Generation including first step']):
    for i,tokens in enumerate([200,512]):
        for j,label in enumerate('AB'):
            values=[a[key] for a in data['arms'] if a['generated_tokens']==tokens and a['label']==label]
            value=sum(values)/len(values); x=i+(j-.5)*.34
            ax.bar(x,value,width=.3,color=colors[j],label=['Previous champion','New champion'][j] if i==0 else None)
            ax.plot([x-.035,x+.035],values,'o',color='#182330',ms=3,zorder=3)
            ax.text(x,value+.42,f'{value:.2f}',ha='center',fontsize=10,fontweight='bold')
    ax.set_title(title,loc='left',fontweight='bold',pad=14)
    ax.set_xticks([0,1],['200 generated','512 generated'])
    ax.set_ylim(0,22);ax.set_axisbelow(True);ax.yaxis.grid(True,color='#e5e9ed')
    for side in ['top','right','left']:ax.spines[side].set_visible(False)
    ax.spines['bottom'].set_color('#c6cfd7');ax.tick_params(axis='both',length=0,pad=8)
axes[0].set_ylabel('tokens / second')
fig.suptitle('DeepSeek V4.1 Flash Q4 · three SSDs',x=.065,ha='left',fontsize=17,fontweight='bold',y=.99)
fig.text(.065,.91,'M5 Max · 128 GiB · 512 prompt tokens · two runs per configuration and length',color='#536477',fontsize=10)
fig.legend(*axes[0].get_legend_handles_labels(),loc='lower center',ncol=2,frameon=False,bbox_to_anchor=(.5,-.01))
fig.subplots_adjust(top=.77,bottom=.20,left=.065,right=.98,wspace=.16)
fig.savefig(root/'comparison.svg',metadata={'Date':None,'Creator':'Argonaut Labs'})
fig.savefig(root/'comparison.png',dpi=180,metadata={'Software':'Argonaut Labs'})

# Keep generated SVG paths free of trailing whitespace.
svg = root / 'comparison.svg'
svg.write_text('\n'.join(line.rstrip() for line in svg.read_text().splitlines()) + '\n')
