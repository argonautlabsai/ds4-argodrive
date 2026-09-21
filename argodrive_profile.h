/* Bounded decode-stage diagnostic. No request logging or added GPU waits.
 * All records belong to the single model worker and are written once at exit.
 * 'drain' includes the existing end_commands API; it is not pure GPU time. */
#ifndef ARGODRIVE_PROFILE_H
#define ARGODRIVE_PROFILE_H
#include <stdio.h>
#include <stdlib.h>
typedef struct { unsigned pos; double total,engram,layer,drain,logits; double detail[9]; } ar_step_time;
#if defined(__APPLE__) && !defined(DS4_NO_GPU)
extern void ar_gpu_profile_snapshot(double out[9]);
#else
static void ar_gpu_profile_snapshot(double out[9]) { for (int i=0;i<9;i++) out[i]=0; }
#endif
static ar_step_time ar_steps[8192];
static unsigned ar_step_count,ar_step_dropped;
static const char *ar_timing_path;
static void ar_timing_flush(void) {
    if (!ar_timing_path) return;
    FILE *f=fopen(ar_timing_path,"wx");
    if(!f) return;
    fprintf(f,"pos,total_ms,engram_ms,layer_body_ms,command_end_ms,logits_ms,gpu_cb_span_ms,cpu_cb_wait_ms,cb_count,expert_pread_ms,expert_prepare_ms,expert_install_ms,selected_sync_ms,missing_experts,resident_experts\n");
    for(unsigned i=0;i<ar_step_count;i++) {
        ar_step_time *t=&ar_steps[i];
        fprintf(f,"%u,%.6f,%.6f,%.6f,%.6f,%.6f",t->pos,1e3*t->total,1e3*t->engram,1e3*t->layer,1e3*t->drain,1e3*t->logits);
        for (unsigned j=0;j<9;j++) fprintf(f,",%.6f",t->detail[j]);
        fputc('\n',f);
    }
    fprintf(f,"# dropped=%u\n",ar_step_dropped);
    fclose(f);
}
static int ar_timing_enabled(void) {
    static int initialized;
    if(!initialized) {
        initialized=1;
        ar_timing_path=getenv("DS4_ARGODRIVE_TIMELINE");
        if(ar_timing_path && *ar_timing_path) atexit(ar_timing_flush);
        else ar_timing_path=NULL;
    }
    return ar_timing_path!=NULL;
}
static void ar_timing_add(ar_step_time t) {
    if(ar_step_count<sizeof(ar_steps)/sizeof(*ar_steps)) ar_steps[ar_step_count++]=t;
    else ar_step_dropped++;
}
/* First-use CPU join telemetry. Read completion only after the existing join;
 * no probe inserts an additional GPU or reader wait. */
typedef struct {
    unsigned pos;
    double queued0, start0, done0, queued1, start1, done1, join_start, join_end;
    int ok;
} ar_engram_join_time;
static ar_engram_join_time ar_engram_joins[8192];
static unsigned ar_engram_join_count, ar_engram_join_dropped;
static const char *ar_engram_join_path;
static void ar_engram_join_flush(void) {
    char path[4096];
    int n=snprintf(path,sizeof(path),"%s.joins.csv",ar_engram_join_path);
    FILE *f=n>0 && (size_t)n<sizeof(path) ? fopen(path,"wx") : NULL;
    if (!f) return;
    fprintf(f,"pos,queued0,start0,done0,queued1,start1,done1,join_start,join_end,ok\n");
    for (unsigned i=0;i<ar_engram_join_count;i++) {
        const ar_engram_join_time *r=&ar_engram_joins[i];
        fprintf(f,"%u,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%d\n",
            r->pos,r->queued0,r->start0,r->done0,r->queued1,r->start1,r->done1,r->join_start,r->join_end,r->ok);
    }
    fprintf(f,"# dropped=%u\n",ar_engram_join_dropped);
    fclose(f);
}
static int ar_engram_join_enabled(void) {
    static int checked;
    if (!checked) {
        checked=1;ar_engram_join_path=getenv("DS4_ARGODRIVE_ENGRAM_DIAGNOSTICS");
        if (ar_engram_join_path && *ar_engram_join_path) atexit(ar_engram_join_flush);
        else ar_engram_join_path=NULL;
    }
    return ar_engram_join_path!=NULL;
}
static void ar_engram_join_add(ar_engram_join_time row) {
    if (ar_engram_join_count<8192) ar_engram_joins[ar_engram_join_count++]=row;
    else ar_engram_join_dropped++;
}
#endif
