#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp) { (void)fp; return false; }
static uint32_t q_seed=99817;
static uint32_t q_rand(void) {q_seed^=q_seed<<13;q_seed^=q_seed>>17;q_seed^=q_seed<<5;return q_seed;}

static int check_round(unsigned in, unsigned width) {
 @autoreleasepool {
    assert(ds4_gpu_init());
    size_t bytes=(size_t)in/32*34*width;
    size_t mapped=(bytes+16383)&~(size_t)16383;
    uint8_t *weights=mmap(NULL,mapped,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
    assert(weights!=MAP_FAILED);
    for(size_t i=0;i<bytes;i++)weights[i]=(uint8_t)q_rand();
    for(size_t i=0;i<bytes;i+=34)((uint16_t*)(weights+i))[0]=0x2000;
    assert(ds4_gpu_set_model_map(weights,mapped));
    ds4_gpu_tensor *x=ds4_gpu_tensor_alloc(in*4),*a=ds4_gpu_tensor_alloc(width*4),*b=ds4_gpu_tensor_alloc(width*4);
    float *input=malloc(in*4),*reference=malloc(width*4),*got=malloc(width*4);
    for(unsigned i=0;i<in;i++)input[i]=((int)(q_rand()%2001)-1000)*0.0001f;
    assert(ds4_gpu_tensor_write(x,0,input,in*4));
    assert(ds4_gpu_begin_commands());
    assert(ds4_gpu_matmul_q8_0_tensor(a,weights,mapped,0,in,width,x,1));
    assert(ds4_gpu_dsv41_quantize(a,width,1,DS4_V41_BF16));
    assert(ds4_gpu_matmul_q8_0_bf16_tensor(b,weights,mapped,0,in,width,x));
    assert(ds4_gpu_end_commands());
    assert(ds4_gpu_tensor_read(a,0,reference,width*4));
    assert(ds4_gpu_tensor_read(b,0,got,width*4));
    int ok=memcmp(reference,got,width*4)==0;
    fprintf(stderr,"Q8 round epilogue %u x %u: %s\n",in,width,ok?"PASS exact":"FAIL");
    free(input);free(reference);free(got);
    ds4_gpu_tensor_free(x);ds4_gpu_tensor_free(a);ds4_gpu_tensor_free(b);
    ds4_gpu_cleanup();munmap(weights,mapped);return ok;
 }
}
int main(void) {return check_round(256,256)&&check_round(2304,5120)&&check_round(5120,2304)?0:1;}
