#ifndef NATSUK1_BRIDGING_H
#define NATSUK1_BRIDGING_H

#include <stdint.h>

typedef struct {
    uint64_t slide;
    uint64_t base;
    int has_rw;
    int has_root;
} nk_ctx_t;

extern nk_ctx_t g_nk;

void nk_set_log(void (*fn)(const char *));
int  nk_run(void);
int  nk_detect_slide(void);
int  nk_full_exploit(void);

#endif
