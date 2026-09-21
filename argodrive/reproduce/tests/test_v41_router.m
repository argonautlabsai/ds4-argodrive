#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp){(void)fp;return false;}
static uint32_t seed=990417;
static uint32_t rnd(void){seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;}
int main(int argc,char **argv){(void)argv;@autoreleasepool{
 unsigned off=argc>1?64:0;
 assert(ds4_gpu_init());
 size_t mapped=16384;float *bias=mmap(NULL,mapped,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);assert(bias!=MAP_FAILED);
 assert(ds4_gpu_set_model_map(bias,mapped));
 ds4_gpu_tensor *lp=ds4_gpu_tensor_alloc(400*4+64),*pp=ds4_gpu_tensor_alloc(400*4+64),*ip=ds4_gpu_tensor_alloc(16*4+64),*wp=ds4_gpu_tensor_alloc(16*4+64);
 ds4_gpu_tensor *logits=ds4_gpu_tensor_view(lp,off,400*4),*probs=ds4_gpu_tensor_view(pp,off,400*4),*ids=ds4_gpu_tensor_view(ip,off,16*4),*weights=ds4_gpu_tensor_view(wp,off,16*4);
 float *bias_values=bias+off/4;
 float input[400],p[400],pr[400],w[16],wr[16];int sel[16],sr[16];
 const char *modes[]={"0","1","2","3","4","invalid"};
 for(unsigned c=0;c<84;c++){
  unsigned n=c<80?384:256;bool has_bias=c%2;float scale=(c%3==0)?1.5f:(c%3==1)?2.5f:1.0f;
  for(unsigned i=0;i<n;i++){
   input[i]=((int)(rnd()%20001)-10000)*.003f;
   bias_values[i]=((int)(rnd()%2001)-1000)*.0001f;
   if(c%7==0){input[i]=0;bias_values[i]=0;}
   if(c%7==1){input[i]=(float)(i%6);bias_values[i]=0;}
   if(c%7==2){input[i]=-100;bias_values[i]=0;}
   if(c%7==3){input[i]=(i%2==0)?20.0f:20.000002f;bias_values[i]=0;}
   if(c%7==4){input[i]=-0.0f;bias_values[i]=(i%2==0)?0.0f:-0.0f;}
   if(c%7==5 && i==2)input[i]=INFINITY;
  }
  assert(ds4_gpu_tensor_write(logits,0,input,n*4));
  for(unsigned mode=0;mode<6;mode++){
   for(unsigned i=0;i<400;i++)p[i]=45321.0f;
   for(unsigned i=0;i<16;i++){sel[i]=123456;w[i]=43215.0f;}
   assert(ds4_gpu_tensor_write(probs,0,p,sizeof(p)));assert(ds4_gpu_tensor_write(ids,0,sel,sizeof(sel)));assert(ds4_gpu_tensor_write(weights,0,w,sizeof(w)));
   setenv("DS4_ARGODRIVE_V41_ROUTER_FUSION",modes[mode],1);
   assert(ds4_gpu_begin_commands());
   assert(ds4_gpu_router_select_tensor(ids,weights,probs,bias,mapped,off,0,0,11,n,6,scale,0,0,has_bias,false,logits));
   assert(ds4_gpu_end_commands());
   assert(ds4_gpu_tensor_read(probs,0,p,sizeof(p)));assert(ds4_gpu_tensor_read(ids,0,sel,sizeof(sel)));assert(ds4_gpu_tensor_read(weights,0,w,sizeof(w)));
   if(mode==0){memcpy(pr,p,sizeof(p));memcpy(sr,sel,sizeof(sel));memcpy(wr,w,sizeof(w));}
   else if(memcmp(pr,p,sizeof(p))||memcmp(sr,sel,sizeof(sel))||memcmp(wr,w,sizeof(w))){
    fprintf(stderr,"FAIL router case%u n%u mode%s bias%d scale%g probs%d ids%d weights%d\n",c,n,modes[mode],has_bias,scale,memcmp(pr,p,sizeof(p)),memcmp(sr,sel,sizeof(sel)),memcmp(wr,w,sizeof(w)));
    for(unsigned i=0;i<6;i++)fprintf(stderr,"%u: id%d/%d weight%.9g/%.9g bits%x/%x\n",i,sr[i],sel[i],wr[i],w[i],((unsigned*)wr)[i],((unsigned*)w)[i]);
    return 1;
   }
  }
 }
 fprintf(stderr,"PASS router: 84 cases, 4 fusion modes, exact probabilities/IDs/weights, ties, tiny/extreme scores, bias on/off, three scales, 256 fallback, canaries\n");
 ds4_gpu_tensor_free(logits);ds4_gpu_tensor_free(probs);ds4_gpu_tensor_free(ids);ds4_gpu_tensor_free(weights);ds4_gpu_tensor_free(lp);ds4_gpu_tensor_free(pp);ds4_gpu_tensor_free(ip);ds4_gpu_tensor_free(wp);ds4_gpu_cleanup();munmap(bias,mapped);return 0;
}}
