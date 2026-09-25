#ifndef __IPDBG_WAVEFORM_GENERATOR_H__
#define __IPDBG_WAVEFORM_GENERATOR_H__

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifndef __ELF__
    #include <windows.h>
#endif

/* IPDBG_STATIC: the library sources are compiled directly into a program or module */
#if defined IPDBG_STATIC
    #define API
#elif defined __ELF__
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

struct IpdbgWaveformGeneratorHandle;

/* same values as in BusAccess.h, both headers can be included together */
#define RET_ERROR -1
#define RET_OK     0

struct IpdbgWaveformGeneratorHandle API *IpdbgWaveformGenerator_new();
int API IpdbgWaveformGenerator_delete(struct IpdbgWaveformGeneratorHandle *handle);
int API IpdbgWaveformGenerator_open(struct IpdbgWaveformGeneratorHandle *handle, const char *ipAddrStr, const char *portNumberStr);
int API IpdbgWaveformGenerator_close(struct IpdbgWaveformGeneratorHandle *handle);
int API IpdbgWaveformGenerator_isOpen(struct IpdbgWaveformGeneratorHandle *handle);

/** Description of the last error, "" if the last call succeeded.
 *  Valid until the next call with the same handle. Never NULL. **/
const char API *IpdbgWaveformGenerator_getLastError(struct IpdbgWaveformGeneratorHandle *handle);

/** widths in bits, as reported by the core **/
int API IpdbgWaveformGenerator_getDataWidth(struct IpdbgWaveformGeneratorHandle *handle, size_t *bits);
int API IpdbgWaveformGenerator_getAddressWidth(struct IpdbgWaveformGeneratorHandle *handle, size_t *bits);
/** size of the sample memory: 2^address width **/
int API IpdbgWaveformGenerator_getMaxSamples(struct IpdbgWaveformGeneratorHandle *handle, size_t *samples);

int API IpdbgWaveformGenerator_getStatus(struct IpdbgWaveformGeneratorHandle *handle, bool *running, bool *doubleBuffer);

/** Writes count samples (1 ... max samples) to the sample memory.
 *  samples: count * ceil(data width / 8) bytes, each sample least significant byte first. **/
int API IpdbgWaveformGenerator_write(struct IpdbgWaveformGeneratorHandle *handle, const uint8_t *samples, size_t count);

int API IpdbgWaveformGenerator_start(struct IpdbgWaveformGeneratorHandle *handle);
int API IpdbgWaveformGenerator_stop(struct IpdbgWaveformGeneratorHandle *handle);
int API IpdbgWaveformGenerator_oneShot(struct IpdbgWaveformGeneratorHandle *handle);

#ifdef __cplusplus
}
#endif

#endif
