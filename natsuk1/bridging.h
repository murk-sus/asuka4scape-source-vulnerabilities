#ifndef NATSUK1_BRIDGING_H
#define NATSUK1_BRIDGING_H

#include <stdint.h>
#include <stddef.h>

typedef struct {
    uint64_t slide;
    uint64_t base;
    int      has_rw;
    int      has_root;
    int      kaslr_confidence;
} nk_ctx_t;

extern nk_ctx_t g_nk;

void nk_set_log(void (*fn)(const char *));
void nk_log(const char *fmt, ...);
void nk_rule(void);

int  nk_detect_slide(void);
int  nk_run(void);
int  nk_full_exploit(void);

uint64_t nk_get_slide(void);
uint64_t nk_get_base(void);
int      nk_get_confidence(void);
int      nk_get_has_kread(void);
int      nk_get_has_kwrite(void);
int      nk_get_has_root(void);

#endif