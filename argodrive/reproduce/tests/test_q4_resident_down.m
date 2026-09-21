/* Exercise save/resume against the unchanged fused kernel, including odd
 * output sizes and every possible first missing slot. No model is needed. */
#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp) { (void)fp; return false; }

static uint32_t rd_seed=8731;
static uint32_t rd_rand(void) { rd_seed^=rd_seed<<13;rd_seed^=rd_seed>>17;rd_seed^=rd_seed<<5;return rd_seed; }

static int check_down(uint32_t in, uint32_t width) {
 @autoreleasepool {
    const size_t row=(in/256)*144, wb=row*width;
    NSMutableArray *owners=[NSMutableArray array];
    __unsafe_unretained id<MTLBuffer> weights[6];
    NSUInteger offsets[6]={0};
    for (unsigned i=0;i<6;i++) {
        id<MTLBuffer> buf=[g_device newBufferWithLength:wb options:MTLResourceStorageModeShared];
        if(!buf)return 0;[owners addObject:buf];weights[i]=buf;
        uint8_t *p=buf.contents;for(size_t j=0;j<wb;j++)p[j]=(uint8_t)rd_rand();
        for(size_t j=0;j<wb;j+=144){((uint16_t*)(p+j))[0]=0x1800;((uint16_t*)(p+j))[1]=0x1000;}
    }
    id<MTLBuffer> mid=[g_device newBufferWithLength:6*in*4 options:MTLResourceStorageModeShared];
    id<MTLBuffer> dst=[g_device newBufferWithLength:(width+8)*4 options:MTLResourceStorageModeShared];
    id<MTLBuffer> carry=[g_device newBufferWithLength:(width*32+8)*4 options:MTLResourceStorageModeShared];
    float *x=mid.contents,*out=dst.contents,*state=carry.contents;
    for(unsigned i=0;i<6*in;i++)x[i]=((int)(rd_rand()%2001)-1000)*0.0001f;
    ds4_gpu_mul_mv_id_args args=ds4_gpu_make_mul_mv_id_args(in,width,256,row,wb,6,6,1,
        ds4_gpu_routed_mv_nr0(DS4_METAL_TENSOR_Q4_K));
    args.tp_world=1;
    NSUInteger smem=ds4_gpu_routed_mv_smem(DS4_METAL_TENSOR_Q4_K);
    float *reference=malloc(width*4);
    assert(ds4_gpu_begin_commands());
    assert(ds4_gpu_encode_mul_mv_slots6_sum6(g_batch_cb,g_moe_mul_mv_slots6_q4_k_sum6_pipeline,
        &args,weights,offsets,mid,0,dst,0,smem,2));
    assert(ds4_gpu_end_commands());memcpy(reference,out,width*4);
    for(unsigned split=1;split<6;split++) {
        for(unsigned i=0;i<width+8;i++)out[i]=NAN;
        for(unsigned i=0;i<width*32+8;i++)state[i]=NAN;
        assert(ds4_gpu_begin_commands());
        assert(ds4_gpu_encode_mul_mv_slots6_continuation(g_batch_cb,
            ds4_gpu_get_mul_mv_pipeline("kernel_mul_mv_slots6_q4_K_prefix_f32",2),
            &args,weights,offsets,mid,0,dst,0,smem,2,carry,split));
        assert(ds4_gpu_end_commands());
        for(unsigned i=0;i<width+8;i++)assert(isnan(out[i]));
        for(unsigned i=width*32;i<width*32+8;i++)assert(isnan(state[i]));
        assert(ds4_gpu_begin_commands());
        assert(ds4_gpu_encode_mul_mv_slots6_continuation(g_batch_cb,
            ds4_gpu_get_mul_mv_pipeline("kernel_mul_mv_slots6_q4_K_resume_f32",2),
            &args,weights,offsets,mid,0,dst,0,smem,2,carry,split));
        assert(ds4_gpu_end_commands());
        if(memcmp(reference,out,width*4)) {
            for(unsigned i=0;i<width;i++)if(memcmp(reference+i,out+i,4)){
                fprintf(stderr,"FAIL in=%u width=%u split=%u row=%u ref=%a got=%a\n",in,width,split,i,reference[i],out[i]);break;}
            free(reference);return 0;
        }
        for(unsigned i=width;i<width+8;i++)assert(isnan(out[i]));
    }
    free(reference);fprintf(stderr,"PASS exact resident down in=%u width=%u, all splits + canaries\n",in,width);return 1;
 }
}
int main(void) {
    if(!ds4_gpu_init())return 1;
    int ok=check_down(256,33)&&check_down(2304,5120)&&check_down(2048,5120);
    ds4_gpu_cleanup();return ok?0:1;
}
