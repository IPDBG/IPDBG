#ifndef __IPDBG_BUS_ACCESS_H__
#define __IPDBG_BUS_ACCESS_H__

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifndef __ELF__
    #include <windows.h>
#endif

#if defined __ELF__
    #define API __attribute((visibility("default")))
#elif defined EXPORT
    #define API __declspec(dllexport)
#else
    #define API __declspec(dllimport)
#endif



#ifdef __cplusplus
extern "C"
{
#endif

struct IpdbgBusAccessHandle;

enum BusAccessField
{
    ADDRESS    = 0,
    READ_DATA  = 1,
    WRITE_DATA = 2,
    STROBE     = 3,
    MISC       = 4
};

#define RET_ERROR -1
#define RET_OK     0
#define RET_NAK    1
#define RET_ACK    2

/** axi4l AxPROT and apb pprot flags:  **/
#define UnprivilegedAccess  0x0
#define PrivilegedAccess    0x1
#define SecureAccess        0x0
#define NonSecureAccess     0x2
#define DataAccess          0x0
#define InstructionAccess   0x4

/** avalon debug flags **/
#define DebugAccess         0x1
#define NonDebugAccess      0x0

/** ahb flags **/
#define H_OpcodeFetch      0x00
#define H_DataAccess       0x01
#define H_UserAccess       0x00
#define H_PrivilegedAccess 0x02
#define H_NonBufferable    0x00
#define H_Bufferable       0x04
#define H_NonCacheable     0x00
#define H_Cacheable        0x08
#define H_DontLookup       0x00
#define H_Lookup           0x10
#define H_DontAllocate     0x00
#define H_Allocate         0x20
#define H_NonShareable     0x00
#define H_Shareable        0x40



struct IpdbgBusAccessHandle API *IpdbgBusAccess_new();
int API IpdbgBusAccess_delete(struct IpdbgBusAccessHandle *handle);
int API IpdbgBusAccess_open(struct IpdbgBusAccessHandle *handle, const char *ipAddrStr, const char *portNumberStr);
int API IpdbgBusAccess_close(struct IpdbgBusAccessHandle *handle);
int API IpdbgBusAccess_isOpen(struct IpdbgBusAccessHandle *handle);
int API IpdbgBusAccess_write_ctrllock(struct IpdbgBusAccessHandle *handle, const uint8_t *address, const uint8_t *data, bool locked);
int API IpdbgBusAccess_read_ctrllock(struct IpdbgBusAccessHandle *handle, const uint8_t *address, uint8_t *result, bool locked);
int API IpdbgBusAccess_setMiscellaneous(struct IpdbgBusAccessHandle *handle, const uint8_t *data);
int API IpdbgBusAccess_setStrobe(struct IpdbgBusAccessHandle *handle, const uint8_t *data);

int API IpdbgBusAccess_getFieldSize(struct IpdbgBusAccessHandle *handle, enum BusAccessField, size_t *result);
int API IpdbgBusAccess_write(struct IpdbgBusAccessHandle *handle, const uint8_t *address, const uint8_t *data);
int API IpdbgBusAccess_read(struct IpdbgBusAccessHandle *handle, const uint8_t *address, uint8_t *result);
int API IpdbgBusAccess_read_modify_write(struct IpdbgBusAccessHandle *handle, const uint8_t *address, void(*modify)(uint8_t *buffer));

int API IpdbgAxi4lAccess_setAxprot(struct IpdbgBusAccessHandle *handle, uint8_t arprot, uint8_t awprot);
int API IpdbgApbAccess_setPprot(struct IpdbgBusAccessHandle *handle, uint8_t pprot);
int API IpdbgAvalonAccess_setDebugAccess(struct IpdbgBusAccessHandle *handle, uint8_t debug);
int API IpdbgAhbAccess_setHprotHsize(struct IpdbgBusAccessHandle *handle, uint8_t hprot, uint8_t hsize);

int API IpdbgDtm_setResets(struct IpdbgBusAccessHandle *handle, bool reset, bool hardreset);

#ifdef __cplusplus
}
#endif

#endif
