#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp) {(void)fp;return false;}
static uint32_t seed=12351;
static uint32_t rnd(void){seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;}
int main(void){@autoreleasepool{
assert(ds4_gpu_init());size_t size=65536;
float *map=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);assert(map!=MAP_FAILED);
for(unsigned i=0;i<size/4;i++)map[i]=((int)(rnd()%2001)-1000)*0.001f;
assert(ds4_gpu_set_model_map(map,size));unsigned shapes[]={4,128,512,1024,5120,20480/4};
for(unsigned caseid=0;caseid<6;caseid++)for(unsigned variant=0;variant<4;variant++){
 unsigned n=shapes[caseid];float *x=malloc(n*4),*ref=malloc(n*4),*got=malloc(n*4);
 for(unsigned i=0;i<n;i++)x[i]=variant==0?0:((int)(rnd()%2001)-1000)*(variant==1?0.0000001f:variant==2?0.001f:10.0f);
 ds4_gpu_tensor *in=ds4_gpu_tensor_alloc(n*4),*a=ds4_gpu_tensor_alloc(n*4),*b=ds4_gpu_tensor_alloc(n*4);
 assert(ds4_gpu_tensor_write(in,0,x,n*4));assert(ds4_gpu_begin_commands());
 assert(ds4_gpu_rms_norm_weight_tensor(a,in,map,size,0,n,1e-6f));assert(ds4_gpu_dsv41_quantize(a,n,1,DS4_V41_BF16));
 assert(ds4_gpu_dsv41_rms_norm_bf16_tensor(b,in,map,size,0,n,1e-6f));assert(ds4_gpu_end_commands());
 assert(ds4_gpu_tensor_read(a,0,ref,n*4));assert(ds4_gpu_tensor_read(b,0,got,n*4));
 if(memcmp(ref,got,n*4)){fprintf(stderr,"FAIL norm n=%u variant=%u\n",n,variant);return 1;}
 // The original operation permits in-place output; preserve that contract too.
 assert(ds4_gpu_dsv41_rms_norm_bf16_tensor(in,in,map,size,0,n,1e-6f));assert(ds4_gpu_tensor_read(in,0,got,n*4));assert(!memcmp(ref,got,n*4));
 free(x);free(ref);free(got);ds4_gpu_tensor_free(in);ds4_gpu_tensor_free(a);ds4_gpu_tensor_free(b);
 fprintf(stderr,"PASS norm n=%u variant=%u exact and in-place\n",n,variant);
}
ds4_gpu_cleanup();munmap(map,size);return 0;
}}
