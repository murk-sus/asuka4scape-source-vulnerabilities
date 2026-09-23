#ifndef NATSUK1_BRIDGING_H
#define NATSUK1_BRIDGING_H

#include <stdint.h>

typedef struct {
    uint64_t slide;
    uint64_t base;
    int      has_rw;
    int      has_root;
} nk_ctx_t;

extern nk_ctx_t g_nk;

void nk_set_log(void (*fn)(const char *));
void nk_log(const char *fmt, ...);
void nk_rule(void);

uint64_t nk_kaslr_detect(void);
int      nk_detect_slide(void);

int      nk_necp_open(void);
int      nk_kread(uint64_t addr, void *buf, size_t sz);
uint32_t nk_kread32(uint64_t addr);
uint64_t nk_kread64(uint64_t addr);
int      nk_kwrite64(uint64_t addr, uint64_t val);

void     nk_sptm_bypass(void);
uint64_t nk_find_proc(pid_t pid);
int      nk_escalate_root(void);
void     nk_probe_525(void);

int      nk_run(void);
int      nk_full_exploit(void);

#endif
