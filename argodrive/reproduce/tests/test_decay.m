#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp){(void)fp;return false;}
int main(int argc,char **argv){
 assert(argc==3);setenv("DS4_ARGODRIVE_DECAY_TOKENS",argv[1],1);unsigned n=atoi(argv[2]);assert(ar_cache_decay_interval()==n);
 g_stream_expert_cache_decode_tokens=1;g_stream_expert_cache_route_hotness[79][383]=12;
 ds4_gpu_stream_expert_cache_maybe_decay_route_hotness();assert(g_stream_expert_cache_route_hotness[79][383]==12);
 g_stream_expert_cache_decode_tokens=n;ds4_gpu_stream_expert_cache_maybe_decay_route_hotness();assert(g_stream_expert_cache_route_hotness[79][383]==12);
 g_stream_expert_cache_decode_tokens=n+1;ds4_gpu_stream_expert_cache_maybe_decay_route_hotness();assert(g_stream_expert_cache_route_hotness[79][383]==6);
 g_stream_expert_cache_decode_tokens=3*n+1;ds4_gpu_stream_expert_cache_maybe_decay_route_hotness();assert(g_stream_expert_cache_route_hotness[79][383]==1);
 ds4_gpu_stream_expert_cache_reset_route_hotness();assert(g_stream_expert_cache_route_hotness[79][383]==0&&g_stream_expert_cache_hotness_decay_token==3*n+1);
 printf("PASS decay input=%s interval=%u boundary, multiple intervals and reset\n",argv[1],n);return 0;
}
