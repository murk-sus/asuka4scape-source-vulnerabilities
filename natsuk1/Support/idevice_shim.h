#ifndef NATSUK1_IDEVICE_SHIM_H
#define NATSUK1_IDEVICE_SHIM_H
#include <stdint.h>
#include <stddef.h>
#include <sys/socket.h>
typedef socklen_t idevice_socklen_t;
typedef struct IdeviceHandle IdeviceHandle;
typedef struct IdevicePairingFile IdevicePairingFile;
typedef struct LockdowndClientHandle LockdowndClientHandle;
typedef struct IdeviceFfiError {
    int32_t code;
    int32_t sub_code;
    const char *message;
} IdeviceFfiError;
struct IdeviceFfiError *idevice_new_tcp_socket(const struct sockaddr *addr,
                                               idevice_socklen_t addr_len,
                                               const char *label,
                                               struct IdeviceHandle **idevice);
struct IdeviceFfiError *lockdownd_new(struct IdeviceHandle *socket,
                                      struct LockdowndClientHandle **client);
struct IdeviceFfiError *lockdownd_pair(struct LockdowndClientHandle *client,
                                       const char *host_id,
                                       const char *system_buid,
                                       const char *host_name,
                                       struct IdevicePairingFile **pairing_file);
struct IdeviceFfiError *idevice_pairing_file_serialize(const struct IdevicePairingFile *pairing_file,
                                                       uint8_t **data,
                                                       uintptr_t *size);
void lockdownd_client_free(struct LockdowndClientHandle *handle);
void idevice_free(struct IdeviceHandle *idevice);
void idevice_pairing_file_free(struct IdevicePairingFile *pairing_file);
void idevice_data_free(uint8_t *data, uintptr_t len);
void idevice_error_free(struct IdeviceFfiError *err);
#endif
