#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp){(void)fp;return false;}
static uint32_t seed=387743;
static uint32_t rnd(void){seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;}
static void check(unsigned k,unsigned a,unsigned b,unsigned mode){@autoreleasepool{
 assert(ds4_gpu_init());size_t n=(size_t)k/32*34;size_t off=n*a;size_t bytes=off+n*b;size_t size=(bytes+16383)&~(size_t)16383;
 unsigned char *map=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);assert(map!=MAP_FAILED);
 for(size_t i=0;i<bytes;i++)map[i]=rnd();for(size_t i=0;i<bytes;i+=34)*(uint16_t*)(map+i)=0x2800;
 assert(ds4_gpu_set_model_map(map,size));ds4_gpu_tensor *x=ds4_gpu_tensor_alloc(k*4),*ref[2],*got[2];unsigned sizes[]={a,b};
 float *in=malloc(k*4);for(unsigned i=0;i<k;i++)in[i]=mode==0?0:((int)(rnd()%2001)-1000)*(mode==1?1e-4f:1.f);
 assert(ds4_gpu_tensor_write(x,0,in,k*4));for(int j=0;j<2;j++){ref[j]=ds4_gpu_tensor_alloc(sizes[j]*4);got[j]=ds4_gpu_tensor_alloc(sizes[j]*4);}
 assert(ds4_gpu_begin_commands());for(int j=0;j<2;j++){
  assert(ds4_gpu_matmul_q8_0_tensor(ref[j],map,size,j?off:0,k,sizes[j],x,1));
  assert(ds4_gpu_dsv41_quantize(ref[j],sizes[j],1,DS4_V41_BF16));
 }
 assert(ds4_gpu_dsv41_qakv_bf16_tensor(got[0],got[1],map,size,0,off,k,a,b,x,1));assert(ds4_gpu_end_commands());
 for(int j=0;j<2;j++){float *r=malloc(sizes[j]*4),*v=malloc(sizes[j]*4);assert(ds4_gpu_tensor_read(ref[j],0,r,sizes[j]*4));assert(ds4_gpu_tensor_read(got[j],0,v,sizes[j]*4));assert(!memcmp(r,v,sizes[j]*4));free(r);free(v);}
 assert(!ds4_gpu_dsv41_qakv_bf16_tensor(got[0],got[1],map,size,0,size-1,k,a,b,x,1));
 for(int j=0;j<2;j++){ds4_gpu_tensor_free(ref[j]);ds4_gpu_tensor_free(got[j]);}free(in);ds4_gpu_tensor_free(x);ds4_gpu_cleanup();munmap(map,size);
 fprintf(stderr,"PASS Q-A/KV BF16 k=%u a=%u b=%u mode=%u\n",k,a,b,mode);
}}
int main(void){for(unsigned m=0;m<3;m++){check(5120,1536,512,m);check(256,64,128,m);check(512,128,128,m);}return 0;}
