#ifndef NATSUK1_BRIDGING_H
#define NATSUK1_BRIDGING_H

#include <stdint.h>

int      nk_full_exploit(void);
void     nk_set_log(int level);

uint64_t nk_get_slide(void);
uint64_t nk_get_base(void);
int      nk_get_confidence(void);
int      nk_get_has_kread(void);
int      nk_get_has_kwrite(void);
int      nk_get_has_root(void);

int      nk_detect_slide(void);

void        nk_log_capture_begin(void);
void        nk_log_capture_end(void);
const char *nk_log_poll(void);

#endif