#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp){(void)fp;return false;}
static void invariant(void){
 for(unsigned l=0;l<80;l++)for(unsigned e=0;e<384;e++)assert(((ar_cache_live[l][e/64]>>(e%64))&1)==!!g_stream_expert_cache[l][e].valid);
}
static void fill(void){
 for(unsigned i=0;i<120;i++){
  unsigned l=(i*13)%80,e=(i*71)%384;
  id<MTLBuffer> b=[g_device newBufferWithLength:768 options:MTLResourceStorageModeShared];assert(b);*(uint32_t*)b.contents=l*384+e;
  ds4_gpu_stream_expert_cache_entry *v=ds4_gpu_stream_expert_cache_install_loaded(NULL,0,l,e,0,0,0,256,256,b,b,b,0,256,512);assert(v);
  v->last_used=i%7;g_stream_expert_cache_route_hotness[l][e]=i%5;
 }
 // Lowest-index entry is in flight; next is explicitly protected by caller.
 g_stream_expert_cache[0][0].inflight_seq=g_stream_expert_cache_done_seq+1;
 ds4_gpu_stream_expert_cache_clear_entry(0,0,1);assert(g_stream_expert_cache[0][0].valid);
 invariant();
}
int main(void){@autoreleasepool{
 assert(ds4_gpu_init());ds4_gpu_set_ssd_streaming(true);g_stream_expert_cache_budget_override=1;
 uint32_t seq[2][115]={0};int32_t protect=71;
 for(unsigned mode=0;mode<2;mode++){
  setenv("DS4_ARGODRIVE_LIVE_SCAN",mode?"1":"0",1);fill();
  for(unsigned i=0;i<115;i++){
   ds4_gpu_stream_expert_reusable_buffers b={0};
   assert(ds4_gpu_stream_expert_cache_take_reusable(1,13,&protect,1,256,256,&b));
   seq[mode][i]=*(uint32_t*)b.gate_buffer.contents;assert(seq[mode][i]!=0&&seq[mode][i]!=13*384+71);invariant();
  }
  ds4_gpu_stream_expert_cache_clear_all(1);invariant();
 }
 assert(!memcmp(seq[0],seq[1],sizeof(seq[0])));
 // Batch reuse must make the same tie decisions and return order too.
 uint32_t bat[2][100]={0};
 for(unsigned mode=0;mode<2;mode++){
  setenv("DS4_ARGODRIVE_LIVE_SCAN",mode?"1":"0",1);fill();
  for(unsigned i=0;i<20;i++){
   ds4_gpu_stream_expert_reusable_buffers b[5]={0};
   assert(ds4_gpu_stream_expert_cache_take_reusable_batch(5,13,&protect,1,256,256,b)==5);
   for(unsigned j=0;j<5;j++)bat[mode][i*5+j]=*(uint32_t*)b[j].gate_buffer.contents;
   invariant();
  }
  ds4_gpu_stream_expert_cache_clear_all(1);invariant();
 }
 assert(!memcmp(bat[0],bat[1],sizeof(bat[0])));
 // Boundary iterator across empty words and the final expert.
 ar_cache_live[79][5]=UINT64_C(1)<<63;assert(ar_cache_next(79,0,1)==383);assert(ar_cache_next(79,384,1)==384);ar_cache_live[79][5]=0;
 ds4_gpu_cleanup();puts("PASS live scan: 115 victim choices identical under ties, protected and in-flight entries retained, bitmap validity through install/clear/rebuild, word boundaries.");return 0;
}}
