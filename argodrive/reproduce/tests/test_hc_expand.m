#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp){(void)fp;return false;}
static uint32_t seed=77877;
static uint32_t rnd(void){seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;}
static void check(unsigned width,unsigned rows,int inplace,int zero){@autoreleasepool{
 assert(ds4_gpu_init());size_t n=width*4*rows;
 ds4_gpu_tensor *block=ds4_gpu_tensor_alloc(width*rows*4),*res=ds4_gpu_tensor_alloc(n*4),*split=ds4_gpu_tensor_alloc(24*rows*4),*ref=ds4_gpu_tensor_alloc(n*4),*got=ds4_gpu_tensor_alloc(n*4);
 float *x=malloc(n*4),*b=malloc(width*rows*4),*s=malloc(24*rows*4),*a=malloc(n*4),*v=malloc(n*4);
 for(size_t i=0;i<n;i++)x[i]=zero?0:((int)(rnd()%2001)-1000)*.03125f;
 for(unsigned i=0;i<width*rows;i++)b[i]=zero?0:((int)(rnd()%2001)-1000)*.001f;
 for(unsigned i=0;i<24*rows;i++)s[i]=((int)(rnd()%2001)-1000)*.0001f;
 assert(ds4_gpu_tensor_write(block,0,b,width*rows*4));assert(ds4_gpu_tensor_write(res,0,x,n*4));assert(ds4_gpu_tensor_write(split,0,s,24*rows*4));assert(ds4_gpu_tensor_write(got,0,x,n*4));
 assert(ds4_gpu_begin_commands());assert(ds4_gpu_hc_expand_split_tensor(ref,block,res,split,width,4));assert(ds4_gpu_dsv41_quantize(ref,width*4,rows,DS4_V41_BF16));
 assert(ds4_gpu_dsv41_hc_expand_bf16(got,block,inplace?got:res,split,width,4));assert(ds4_gpu_end_commands());
 assert(ds4_gpu_tensor_read(ref,0,a,n*4));assert(ds4_gpu_tensor_read(got,0,v,n*4));assert(!memcmp(a,v,n*4));assert(!ds4_gpu_dsv41_hc_expand_bf16(got,block,res,split,width,3));
 free(x);free(b);free(s);free(a);free(v);ds4_gpu_tensor_free(block);ds4_gpu_tensor_free(res);ds4_gpu_tensor_free(split);ds4_gpu_tensor_free(ref);ds4_gpu_tensor_free(got);ds4_gpu_cleanup();
 fprintf(stderr,"PASS HC expand BF16 width%u rows%u alias%d zero%d\n",width,rows,inplace,zero);
}}
int main(void){for(int a=0;a<2;a++)for(int z=0;z<2;z++){check(5120,1,a,z);check(513,3,a,z);check(128,1,a,z);}return 0;}
