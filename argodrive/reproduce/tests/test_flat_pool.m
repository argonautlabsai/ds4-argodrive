/* Exercise the actual persistent pool without loading a model. */
#include <unistd.h>
static int test_hold;
static ssize_t fixture_pread(int fd, void *p, size_t n, off_t off) {
    while(__atomic_load_n(&test_hold,__ATOMIC_ACQUIRE)) usleep(100);
    return pread(fd,p,n,off);
}
#define pread fixture_pread
#include <ds4_metal.m>
#undef pread
#include <assert.h>
bool ds4_log_is_tty(FILE *fp) { (void)fp; return false; }
int main(void) {
    const size_t size=8*1024*1024+123;
    unsigned char *reference=malloc(size);assert(reference);
    for(size_t i=0;i<size;i++) reference[i]=(unsigned char)((i*13+i/4096)%251);
    char dir[]="/tmp/v41-flat-pool-XXXXXX";assert(mkdtemp(dir));
    char path[3][256];int fd[3];
    for(unsigned i=0;i<3;i++) {snprintf(path[i],256,"%s/replica%u",dir,i);fd[i]=open(path[i],O_CREAT|O_EXCL|O_RDWR,0600);assert(fd[i]>=0);assert(write(fd[i],reference,size)==size);}
    char cfg[600];snprintf(cfg,sizeof(cfg),"%s*6,%s*6",path[1],path[2]);
    g_model_fd=fd[0];assert(ar_open(&g_argodrive_reader,fd[0],cfg,"10"));
    setenv("DS4_ARGODRIVE_FLAT_READS","1",1);ar_set_decode_phase(1);
    for(unsigned cycle=0;cycle<3;cycle++) {
        for(unsigned n=3;n<=24;n+=3) {
            ds4_gpu_stream_expert_pread_task tasks[24]={0};
            for(unsigned j=0;j<n;j++) {
                uint64_t length=j==0?17:1000000+j*811;
                unsigned char *buf=malloc(length+32);assert(buf);memset(buf,0x91,length+32);
                tasks[j]=(ds4_gpu_stream_expert_pread_task){.offset=cycle*97+j*1777,.len=length,.dst=buf+16};
            }
            uint64_t before[3];for(unsigned i=0;i<3;i++)before[i]=g_argodrive_reader.source[i].bytes;
            __atomic_store_n(&test_hold,1,__ATOMIC_RELEASE);
            assert(ds4_gpu_stream_expert_pread_pool_begin(tasks,n,ds4_gpu_stream_expert_pread_thread_count(n)));
            assert(!ds4_gpu_stream_expert_pread_pool_begin(tasks,n,3)); /* busy batch cannot be replaced */
            __atomic_store_n(&test_hold,0,__ATOMIC_RELEASE);
            assert(ds4_gpu_stream_expert_pread_pool_wait());
            uint64_t bytes=0,expected=0;
            for(unsigned j=0;j<n;j++) {
                assert(tasks[j].ok && tasks[j].read_bytes==tasks[j].len);
                assert(!memcmp(tasks[j].dst,reference+tasks[j].offset,tasks[j].len));
                for(unsigned k=0;k<16;k++)assert(tasks[j].dst[(int)k-16]==0x91 && tasks[j].dst[tasks[j].len+k]==0x91);
                expected+=tasks[j].len;free(tasks[j].dst-16);
            }
            for(unsigned i=0;i<3;i++)bytes+=g_argodrive_reader.source[i].bytes-before[i];
            assert(bytes==expected);
        }
        ds4_gpu_stream_expert_pread_pool_shutdown();
    }
    assert(g_ar_flat_batches==24);
    /* Real truncated source; every writer is joined before failure is reported. */
    assert(!ftruncate(fd[2],0));
    unsigned char *dst=malloc(size+32);memset(dst,0x91,size+32);
    ds4_gpu_stream_expert_pread_task bad[3]={0};
    for(unsigned i=0;i<3;i++)bad[i]=(ds4_gpu_stream_expert_pread_task){.offset=i*100,.len=1000000,.dst=dst+16+i*1000000};
    uint64_t actual;double wall;
    assert(!ds4_gpu_stream_expert_pread_tasks(bad,3,&actual,&wall));
    assert(actual<3000000 && !bad[0].ok && !bad[1].ok && !bad[2].ok);
    unsigned char *snapshot=malloc(size+32);memcpy(snapshot,dst,size+32);usleep(20000);assert(!memcmp(snapshot,dst,size+32));free(snapshot);
    assert(pwrite(fd[2],reference,size,0)==size);
    assert(ds4_gpu_stream_expert_pread_tasks(bad,3,&actual,&wall));
    assert(actual==3000000);
    /* Prefill and flag-off retain the original path. */
    uint64_t batches=g_ar_flat_batches;ar_set_decode_phase(0);
    assert(ds4_gpu_stream_expert_pread_tasks(bad,3,&actual,&wall));assert(g_ar_flat_batches==batches);
    ar_set_decode_phase(1);setenv("DS4_ARGODRIVE_FLAT_READS","0",1);
    assert(ds4_gpu_stream_expert_pread_tasks(bad,3,&actual,&wall));assert(g_ar_flat_batches==batches);
    ds4_gpu_stream_expert_pread_pool_shutdown();ar_close(&g_argodrive_reader);
    for(unsigned i=0;i<3;i++){close(fd[i]);unlink(path[i]);}rmdir(dir);free(dst);free(reference);
    puts("PASS flat pool: 24 batches, 3 lifetimes, 3-24 components, odd ranges and zero pieces, byte accounting, busy refusal, canaries, real EOF, joined failure, recovery, prefill and flag-off fallback.");
    return 0;
}
