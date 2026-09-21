#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp) {(void)fp;return false;}
static uint32_t seed=984731;
static uint32_t rnd(void){seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;}
int main(void){@autoreleasepool{
assert(ds4_gpu_init());size_t size=65536;
float *map=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);assert(map!=MAP_FAILED);
for(unsigned i=0;i<size/4;i++)map[i]=((int)(rnd()%2001)-1000)*0.001f;
assert(ds4_gpu_set_model_map(map,size));unsigned shapes[]={4,128,512,1024,5120};
for(unsigned c=0;c<5;c++)for(unsigned v=0;v<5;v++){
 unsigned n=shapes[c],hc=4;float *x=malloc(n*hc*4),*ref=malloc(n*4),*got=malloc(n*4),weight[24];
 for(unsigned i=0;i<n*hc;i++)x[i]=v==0?0:((int)(rnd()%2001)-1000)*(v==1?0.0000001f:v==2?0.001f:10.0f);
 for(unsigned i=0;i<24;i++)weight[i]=((int)(rnd()%2001)-1000)*0.001f;
 ds4_gpu_tensor *in=ds4_gpu_tensor_alloc(n*hc*4),*w=ds4_gpu_tensor_alloc(sizeof(weight)),*a[2],*b[2];
 for(unsigned i=0;i<2;i++){a[i]=ds4_gpu_tensor_alloc(n*4);b[i]=ds4_gpu_tensor_alloc(n*4);}
 assert(ds4_gpu_tensor_write(in,0,x,n*hc*4));assert(ds4_gpu_tensor_write(w,0,weight,sizeof(weight)));
 assert(ds4_gpu_begin_commands());
 if(v==4)assert(ds4_gpu_hc_weighted_sum_split_tensor(a[0],in,w,n,hc));
 else assert(ds4_gpu_hc_weighted_sum_tensor(a[0],in,w,n,hc));
 assert(ds4_gpu_dsv41_quantize(a[0],n,1,DS4_V41_BF16));
 assert(ds4_gpu_rms_norm_weight_tensor(a[1],a[0],map,size,0,n,1e-6f));assert(ds4_gpu_dsv41_quantize(a[1],n,1,DS4_V41_BF16));
 assert(ds4_gpu_dsv41_hc_sum_norm_tensor(b[1],b[0],in,w,map,size,0,n,hc,1e-6f));assert(ds4_gpu_end_commands());
 for(unsigned j=0;j<2;j++){
 assert(ds4_gpu_tensor_read(a[j],0,ref,n*4));assert(ds4_gpu_tensor_read(b[j],0,got,n*4));
 if(memcmp(ref,got,n*4)){unsigned bad=0;for(unsigned i=0;i<n;i++)if(memcmp(ref+i,got+i,4)){if(bad++<4)fprintf(stderr,"mismatch output %u idx %u: %.9g %.9g\n",j,i,ref[i],got[i]);}fprintf(stderr,"FAIL HC norm n=%u variant=%u (%u)\n",n,v,bad);return 1;}
 }
 assert(!ds4_gpu_dsv41_hc_sum_norm_tensor(b[1],b[0],in,w,map,size,size,n,hc,1e-6f));
 free(x);free(ref);free(got);ds4_gpu_tensor_free(in);ds4_gpu_tensor_free(w);for(unsigned i=0;i<2;i++){ds4_gpu_tensor_free(a[i]);ds4_gpu_tensor_free(b[i]);}
 fprintf(stderr,"PASS HC norm n=%u variant=%u sum/norm exact\n",n,v);
}
ds4_gpu_cleanup();munmap(map,size);return 0;
}}
