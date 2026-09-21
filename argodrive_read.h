/* Experimental expert-only replica reader. Callers must verify full replicas
 * before admission; size and inode checks are not content verification. */
#ifndef ARGODRIVE_READ_H
#define ARGODRIVE_READ_H
#include <dispatch/dispatch.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <limits.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>

/* reads/lands_last/gap_ns: barrier attribution, see ar_read. Trailing fields
 * so the positional initialisers below keep zeroing them. */
typedef struct { int fd; unsigned weight; uint64_t bytes; uint64_t reads, lands_last, gap_ns; unsigned decode_weight; uint64_t syscalls; } ar_source;
/* Argodrive 2026-09-19: DS4_ARGODRIVE_DECODE_WEIGHTS="10,6,6" (primary first, then the
 * replicas in DS4_ARGODRIVE_REPLICAS order) gives decode its own split; prefill keeps the
 * base weights. The engine flips ar_decode_phase at the first decode expert load and
 * clears it when a prefill stage begins. */
static volatile int g_ar_decode_phase;
static void ar_set_decode_phase(int on) { g_ar_decode_phase = on ? 1 : 0; }
static unsigned ar_effective_weight(const ar_source *src) {
    return (g_ar_decode_phase && src->decode_weight) ? src->decode_weight : src->weight;
}
typedef struct { ar_source source[3]; unsigned count; int invalid; int owns_primary; uint64_t size; } ar_reader;
typedef struct { uint64_t offset, length; } ar_piece;

/* Optional per-component timing, written once after readers have quiesced.
 * Timers share CLOCK_MONOTONIC_RAW. Byte/latency records are not device I/O. */
typedef struct {
    uint64_t offset, length, begin, end, start[3], done[3], bytes[3], batch;
    unsigned sources; int ok;
} ar_read_time;
static ar_read_time *ar_read_times;
static uint64_t ar_read_time_count;
static const char *ar_read_time_path;
static __thread uint64_t ar_read_batch;
#define AR_READ_TIME_CAP 65536u
static void ar_read_time_flush(void) {
    if (!ar_read_times) return;
    FILE *f=fopen(ar_read_time_path,"wx");
    uint64_t n=__atomic_load_n(&ar_read_time_count,__ATOMIC_RELAXED);
    if (f) {
        fprintf(f,"offset,length,batch,begin_ns,end_ns,start0_ns,done0_ns,bytes0,start1_ns,done1_ns,bytes1,start2_ns,done2_ns,bytes2,sources,ok\n");
        for (uint64_t i=0;i<n && i<AR_READ_TIME_CAP;i++) {
            ar_read_time *r=&ar_read_times[i];
            fprintf(f,"%llu,%llu,%llu,%llu,%llu",(unsigned long long)r->offset,(unsigned long long)r->length,
                (unsigned long long)r->batch,(unsigned long long)r->begin,(unsigned long long)r->end);
            for(unsigned k=0;k<3;k++) fprintf(f,",%llu,%llu,%llu",(unsigned long long)r->start[k],
                (unsigned long long)r->done[k],(unsigned long long)r->bytes[k]);
            fprintf(f,",%u,%d\n",r->sources,r->ok);
        }
        fprintf(f,"# dropped=%llu\n",(unsigned long long)(n>AR_READ_TIME_CAP?n-AR_READ_TIME_CAP:0));
        fclose(f);
    }
    free(ar_read_times);ar_read_times=NULL;
}
static void ar_read_time_init(void) {
    static int checked;
    if (checked) return;
    checked=1;ar_read_time_path=getenv("DS4_ARGODRIVE_READ_TIMING");
    if(ar_read_time_path && *ar_read_time_path) {
        ar_read_times=calloc(AR_READ_TIME_CAP,sizeof(*ar_read_times));
        if(ar_read_times) atexit(ar_read_time_flush);
    }
}
static void ar_close(ar_reader *r) {
    for (unsigned i=0; i<r->count; i++)
        fprintf(stderr,"ds4: Argodrive source[%u] bytes=%llu\n",i,(unsigned long long)__atomic_load_n(&r->source[i].bytes,__ATOMIC_RELAXED));
    /* Barrier attribution, only when a split existed. Kept on its own line so
     * the bytes= line above stays byte-identical for existing parsers. */
    if (r->count>1)
        for (unsigned i=0; i<r->count; i++)
            fprintf(stderr,"ds4: Argodrive source[%u] lands_last=%llu gap_ns=%llu reads=%llu\n",i,
                (unsigned long long)__atomic_load_n(&r->source[i].lands_last,__ATOMIC_RELAXED),
                (unsigned long long)__atomic_load_n(&r->source[i].gap_ns,__ATOMIC_RELAXED),
                (unsigned long long)__atomic_load_n(&r->source[i].reads,__ATOMIC_RELAXED));
    for (unsigned i=r->owns_primary?0:1; i<r->count; i++) close(r->source[i].fd);
    memset(r,0,sizeof(*r));
}
static int ar_weight(const char *s, unsigned *w) {
    if (!s || !*s) return 0;
    for (const char *p=s; *p; p++) if (*p<'0' || *p>'9') return 0;
    char *end; unsigned long n=strtoul(s,&end,10);
    if (*end || n<1 || n>100) return 0;
    *w=(unsigned)n; return 1;
}
static int ar_open(ar_reader *r, int primary, const char *paths, const char *weight) {
    ar_close(r);
    ar_read_time_init();
    const char *uncached_env = getenv("DS4_ARGODRIVE_PRIMARY_NOCACHE");
    const int uncached = uncached_env && strcmp(uncached_env,"0") != 0;
    if ((!paths || !*paths) && !uncached) return 1;
    struct stat st;
    r->invalid=1;
    if (fstat(primary,&st) || !S_ISREG(st.st_mode) || st.st_size<=0) return 0;
    r->size=(uint64_t)st.st_size;
    unsigned w=2;
    if (weight && !ar_weight(weight,&w)) return 0;
    r->source[0]=(ar_source){.fd=primary,.weight=w}; r->count=1;
    if (uncached) {
        // Open an independent expert descriptor. Changing the mmap/Engram
        // descriptor's policy (including through dup) would confound this test.
#if defined(F_GETPATH) && defined(F_NOCACHE)
        char primary_path[4096]; struct stat same;
        if (fcntl(primary,F_GETPATH,primary_path)<0) {ar_close(r);r->invalid=1;return 0;}
        int expert_fd=open(primary_path,O_RDONLY|O_NONBLOCK);
        if (expert_fd<0) {ar_close(r);r->invalid=1;return 0;}
        if (fstat(expert_fd,&same) || same.st_dev!=st.st_dev || same.st_ino!=st.st_ino ||
            same.st_size!=st.st_size || fcntl(expert_fd,F_NOCACHE,1)<0 ||
            fcntl(expert_fd,F_RDAHEAD,0)<0) {
            close(expert_fd);ar_close(r);r->invalid=1;return 0;
        }
        r->source[0].fd=expert_fd;r->owns_primary=1;
        fprintf(stderr,"ds4: Argodrive primary expert descriptor F_NOCACHE=1; mmap/Engram descriptor unchanged\n");
#else
        ar_close(r);r->invalid=1;return 0;
#endif
    }
    if (!paths || !*paths) {r->invalid=0;return 1;}
    /* Strict comma-separated absolute path*integer syntax. */
    char *copy=strdup(paths); if (!copy) {ar_close(r);r->invalid=1;return 0;}
    char *cursor=copy;
    int ok=1;
    while (cursor && *cursor) {
        char *next=strchr(cursor,',');
        if(next) { *next++=0; if(!*next) {ok=0;break;} }
        char *star=strrchr(cursor,'*');
        if(r->count>=3 || !star || cursor[0]!='/' || !ar_weight(star+1,&w)) {ok=0;break;}
        *star=0;
        int fd=open(cursor,O_RDONLY|O_NONBLOCK);
        struct stat replica;
        if(fd<0) {ok=0;break;}
        if(fstat(fd,&replica) || !S_ISREG(replica.st_mode) || replica.st_size!=st.st_size) {close(fd);ok=0;break;}
        for(unsigned i=0;i<r->count;i++) {
            struct stat old;
            if(fstat(r->source[i].fd,&old) || (old.st_dev==replica.st_dev && old.st_ino==replica.st_ino)) ok=0;
        }
        if(!ok) {close(fd);break;}
#ifdef F_NOCACHE
        if(fcntl(fd,F_NOCACHE,1)<0 || fcntl(fd,F_RDAHEAD,0)<0) {close(fd);ok=0;break;}
#endif
        r->source[r->count++]=(ar_source){.fd=fd,.weight=w}; cursor=next;
    }
    free(copy);
    if(!ok || r->count<2) {ar_close(r);r->invalid=1;return 0;}
    {   /* optional decode-phase split, e.g. "10,6,6" */
        const char *dw=getenv("DS4_ARGODRIVE_DECODE_WEIGHTS");
        if(dw && dw[0]) {
            unsigned parsed[3]={0,0,0}; unsigned n=0; const char *c=dw; int good=1;
            while(*c && n<3) { char *end=NULL; unsigned long v=strtoul(c,&end,10); if(end==c || v==0 || v>100) {good=0;break;} parsed[n++]=(unsigned)v; c=end; if(*c==',') c++; else if(*c) {good=0;break;} }
            if(good && n==r->count) { for(unsigned i=0;i<r->count;i++) r->source[i].decode_weight=parsed[i]; fprintf(stderr,"ds4: Argodrive decode split %s (prefill keeps the base weights)\n",dw); }
            else fprintf(stderr,"ds4: ignoring DS4_ARGODRIVE_DECODE_WEIGHTS=%s (want %u comma-separated weights 1..100)\n",dw,r->count);
        }
    }
    r->invalid=0;return 1;
}
static int ar_plan(const ar_reader *r, uint64_t offset, uint64_t length, ar_piece out[3]) {
    if(r->invalid || r->count<1 || r->count>3 || !length || offset>r->size || length>r->size-offset) return 0;
    const uint64_t block=256*1024;
    uint64_t blocks=length/block, counts[3]={0}, remainder[3]={0}, assigned=0;
    unsigned total=0;
    unsigned w[3]={0,0,0};
    for(unsigned i=0;i<r->count;i++) {w[i]=ar_effective_weight(&r->source[i]);if(!w[i] || w[i]>100) return 0;total+=w[i];}
    for(unsigned i=0;i<r->count;i++) {counts[i]=blocks*w[i]/total;remainder[i]=blocks*w[i]%total;assigned+=counts[i];}
    while(assigned<blocks) {
        unsigned best=0;for(unsigned i=1;i<r->count;i++) if(remainder[i]>remainder[best]) best=i;
        counts[best]++;remainder[best]=0;assigned++;
    }
    uint64_t pos=offset;
    for(unsigned i=0;i<r->count;i++) {
        uint64_t n=counts[i]*block+(i==0?length%block:0);
        out[i]=(ar_piece){pos,n};pos+=n;
    }
    return pos-offset==length;
}
static uint64_t ar_exact(ar_source *source,uint64_t offset,uint64_t length,uint8_t *dst) {
    uint64_t n=0;
    while(n<length) {
        size_t want=length-n>SSIZE_MAX?SSIZE_MAX:(size_t)(length-n);
        __atomic_fetch_add(&source->syscalls,1,__ATOMIC_RELAXED);
        ssize_t got=pread(source->fd,dst+n,want,(off_t)(offset+n));
        if(got<0 && errno==EINTR) continue;
        if(got<=0) break;
        n+=(uint64_t)got;
    }
    return n;
}
static int ar_complete(ar_reader *r, const ar_piece pieces[3], const uint64_t counts[3], const uint64_t done_ns[3], uint64_t *bytes) {
    /* Barrier attribution. A split read completes when its slowest slice
     * lands, so charge this read's wait to the source that landed last and
     * record how far behind the next-to-last it was. This observed gap is not
     * a causal estimate of savings from redistributing the read. Pieces of
     * zero length did not take part; a single source has no barrier. */
    if(r->count>1) {
        int last=-1, second=-1;
        for(unsigned i=0;i<r->count;i++) {
            if(!pieces[i].length) continue;
            if(last<0 || done_ns[i]>done_ns[last]) { second=last; last=(int)i; }
            else if(second<0 || done_ns[i]>done_ns[second]) second=(int)i;
        }
        if(last>=0 && second>=0) {
            __atomic_fetch_add(&r->source[last].lands_last,1,__ATOMIC_RELAXED);
            __atomic_fetch_add(&r->source[last].gap_ns,done_ns[last]-done_ns[second],__ATOMIC_RELAXED);
            for(unsigned i=0;i<r->count;i++)
                if(pieces[i].length) __atomic_fetch_add(&r->source[i].reads,1,__ATOMIC_RELAXED);
        }
    }
    int ok=1;
    *bytes=0;
    for(unsigned i=0;i<r->count;i++) {*bytes+=counts[i];if(counts[i]!=pieces[i].length) ok=0;}
    return ok;
}
static int ar_read(ar_reader *r,uint64_t offset,uint64_t length,uint8_t *dst,uint64_t *bytes) {
    *bytes=0;
    ar_piece pieces[3];
    if(!dst || offset>LLONG_MAX || length>LLONG_MAX-offset || !ar_plan(r,offset,length,pieces)) return 0;
    uint64_t counts[3]={0}, done_ns[3]={0}, start_ns[3]={0};
    const int trace=ar_read_times && g_ar_decode_phase;
    const uint64_t begin=trace?clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW):0;
    /* Completion barrier owns dst until all disjoint writes finish, including
     * failures. No partial buffer is accepted or retried while writes remain. */
    ar_piece *pp=pieces; uint64_t *cc=counts, *dn=done_ns, *sn=start_ns;
    dispatch_apply(r->count,dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^(size_t i){
        if(trace) sn[i]=clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
        cc[i]=ar_exact(&r->source[i],pp[i].offset,pp[i].length,dst+(pp[i].offset-offset));
        dn[i]=clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
        __atomic_fetch_add(&r->source[i].bytes,cc[i],__ATOMIC_RELAXED);
    });
    int ok=ar_complete(r,pieces,counts,done_ns,bytes);
    if(trace) {
        uint64_t i=__atomic_fetch_add(&ar_read_time_count,1,__ATOMIC_RELAXED);
        if(i<AR_READ_TIME_CAP) {
            ar_read_time *t=&ar_read_times[i];
            *t=(ar_read_time){.offset=offset,.length=length,.begin=begin,
                .end=clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW),.batch=ar_read_batch,.sources=r->count,.ok=ok};
            memcpy(t->start,start_ns,sizeof(start_ns));memcpy(t->done,done_ns,sizeof(done_ns));memcpy(t->bytes,counts,sizeof(counts));
        }
    }
    return ok;
}
#endif
