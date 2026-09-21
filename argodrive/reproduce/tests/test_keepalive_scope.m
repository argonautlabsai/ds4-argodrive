/* Real GPU lifecycle checks, including a second request after an early end.
 * No model required. Include the runtime to exercise the private gap boundary. */
#include <ds4_metal.m>
#include <assert.h>
bool ds4_log_is_tty(FILE *fp) { (void)fp; return false; }

static void snapshot(uint64_t out[4]) { ds4_gpu_argodrive_keepalive_snapshot(out); }
static void assert_idle(void) {
    uint64_t a[4], b[4]; snapshot(a); usleep(30000); snapshot(b);
    assert(a[0] == b[0]);
}
int main(int argc, char **argv) {
    assert(argc == 2);
    int mode = atoi(argv[1]); assert(mode == 1 || mode == 2);
    setenv("DS4_ARGODRIVE_GAP_KEEPALIVE", argv[1], 1);
    setenv("DS4_TP_KEEPALIVE_TGS", "1", 1);
    setenv("DS4_TP_KEEPALIVE_ITERS", "1000", 1);
    setenv("DS4_METAL_DISABLE_QUEUE_KEEPALIVE", "1", 1);
    for (unsigned lifetime = 0; lifetime < 2; lifetime++) {
        assert(ds4_gpu_init());
        assert_idle();
        for (unsigned request = 0; request < 3; request++) {
            uint64_t a[4], b[4]; snapshot(a);
            ds4_gpu_argodrive_keepalive_token(1, request);
            if (mode == 1) {
                assert_idle();
                ds4_gpu_argodrive_keepalive_gap(1);
            }
            usleep(30000);
            if (mode == 1) ds4_gpu_argodrive_keepalive_gap(0);
            /* An early-failed token uses this same close boundary. */
            ds4_gpu_argodrive_keepalive_token(0, 0);
            snapshot(b);
            assert(b[0] > a[0]);
            assert(b[2] == 0 && b[3] == 0);
            if (mode == 1) assert(b[1] == 0);
            else assert(b[1] > a[1]);
            assert_idle();
        }
        ds4_gpu_cleanup();
        assert(!g_tp_keepalive_running && !g_ar_keepalive_owned);
        assert_idle();
        /* Reproduce the shared stop state left by an earlier TP session. */
        g_tp_shutdown = 1;
    }
    fprintf(stderr, "PASS keepalive mode=%d: idle, admission, repeated request and cleanup/reinit\n", mode);
    return 0;
}
