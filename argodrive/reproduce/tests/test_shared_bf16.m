#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp) { (void)fp; return false; }
static uint32_t seed=0x126538;
static uint32_t rnd(void) {seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;}
static void check(unsigned in,unsigned out,float scale,float limit) {
 @autoreleasepool {
 assert(ds4_gpu_init());
 size_t bytes=(size_t)in/32*34*out, offset=(bytes+16383)&~(size_t)16383, size=offset*2;
 uint8_t *map=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0); assert(map!=MAP_FAILED);
 for(unsigned matrix=0;matrix<2;matrix++){
  uint8_t *w=map+offset*matrix;
  for(size_t i=0;i<bytes;i++)w[i]=(uint8_t)rnd();
  for(size_t i=0;i<bytes;i+=34){__fp16 d=(__fp16)(((int)(rnd()%1001)-500)*0.0001f);memcpy(w+i,&d,2);}
 }
 assert(ds4_gpu_set_model_map(map,size));
 ds4_gpu_tensor *x=ds4_gpu_tensor_alloc(in*4),*a[3],*b[3];
 float *input=malloc(in*4),*ref=malloc(out*4),*got=malloc(out*4);
 for(unsigned i=0;i<in;i++)input[i]=((int)(rnd()%2001)-1000)*scale;
 for(unsigned j=0;j<3;j++){a[j]=ds4_gpu_tensor_alloc(out*4);b[j]=ds4_gpu_tensor_alloc(out*4);assert(a[j]&&b[j]);}
 assert(ds4_gpu_tensor_write(x,0,input,in*4));
 for(unsigned repeat=0;repeat<3;repeat++){
 assert(ds4_gpu_begin_commands());
 for(unsigned j=0;j<2;j++){
  assert(ds4_gpu_matmul_q8_0_tensor(a[j],map,size,j*offset,in,out,x,1));
  assert(ds4_gpu_dsv41_quantize(a[j],out,1,DS4_V41_BF16));
 }
 assert(ds4_gpu_swiglu_tensor(a[2],a[0],a[1],out,limit,1.0f));
 assert(ds4_gpu_dsv41_quantize(a[2],out,1,DS4_V41_BF16));
 assert(ds4_gpu_dsv41_shared_gate_up_swiglu_q8_0_tensor(b[0],b[1],b[2],map,size,0,offset,in,out,x,limit));
 assert(ds4_gpu_end_commands());
 for(unsigned j=0;j<3;j++){
  assert(ds4_gpu_tensor_read(a[j],0,ref,out*4));assert(ds4_gpu_tensor_read(b[j],0,got,out*4));
  if(memcmp(ref,got,out*4)){unsigned bad=0;for(unsigned i=0;i<out;i++)if(memcmp(ref+i,got+i,4)){if(bad++<4)fprintf(stderr,"mismatch projection %u at %u: %.9g %.9g\n",j,i,ref[i],got[i]);}fprintf(stderr,"FAIL %u/%u\n",bad,out);exit(1);}
 }
 }
 fprintf(stderr,"PASS shared BF16 %u x %u scale %g clamp %g: gate/up/mid exact\n",in,out,scale,limit);
 ds4_gpu_tensor_free(x);for(unsigned j=0;j<3;j++){ds4_gpu_tensor_free(a[j]);ds4_gpu_tensor_free(b[j]);}
 free(input);free(ref);free(got);ds4_gpu_cleanup();munmap(map,size);
 }
}
int main(void) {check(256,256,0.0001f,0);check(5120,2304,0.0001f,10);check(5120,2304,0.1f,10);check(5120,2304,0,10);return 0;}
