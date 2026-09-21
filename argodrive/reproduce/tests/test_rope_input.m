#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp){(void)fp;return false;}
static uint32_t seed=5815349;static uint32_t rnd(void){seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;}
int main(void){@autoreleasepool{
 assert(ds4_gpu_init());unsigned widths[]={64,70,128,512},starts[]={0,512,16000};
 for(unsigned wi=0;wi<4;wi++)for(unsigned st=0;st<3;st++)for(unsigned kind=0;kind<4;kind++){
  unsigned width=widths[wi],heads=wi==3?64:3,rows=st==2?3:1,n=width*heads*rows;float *x=malloc(n*4),*a=malloc(n*4),*b=malloc(n*4);
  for(unsigned i=0;i<n;i++)x[i]=((int)(rnd()%2001)-1000)*0.00031f;
  const uint32_t ties[]={0x3f808000,0x3f818000,0x80000000,0,0x00800001};for(unsigned i=0;i<5;i++)memcpy(x+i,ties+i,4);
  ds4_gpu_tensor *ref=ds4_gpu_tensor_alloc(n*4),*got=ds4_gpu_tensor_alloc(n*4);assert(ds4_gpu_tensor_write(ref,0,x,n*4));assert(ds4_gpu_tensor_write(got,0,x,n*4));
  assert(ds4_gpu_begin_commands());assert(ds4_gpu_dsv41_quantize(ref,width,heads*rows,DS4_V41_BF16));assert(ds4_gpu_dsv41_rope(ref,width,heads,rows,starts[st],kind&1,kind&2));
  assert(ds4_gpu_dsv41_rope_bf16_input(got,width,heads,rows,starts[st],kind&1,kind&2));assert(ds4_gpu_end_commands());
  assert(ds4_gpu_tensor_read(ref,0,a,n*4));assert(ds4_gpu_tensor_read(got,0,b,n*4));if(memcmp(a,b,n*4)){fprintf(stderr,"FAIL width=%u start=%u kind=%u\n",width,starts[st],kind);return 1;}
  ds4_gpu_tensor_free(ref);ds4_gpu_tensor_free(got);free(x);free(a);free(b);
 }
 ds4_gpu_cleanup();puts("PASS RoPE input: 48 bit-exact cases, both directions/compression modes, 64/70/128/512 widths, multi-row, RNE ties and signed zero.");return 0;
}}
