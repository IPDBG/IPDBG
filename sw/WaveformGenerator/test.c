/* Example for the IPDBG WaveformGenerator C API:
 * writes a sawtooth that covers the full data width and starts the generator.
 *
 *   test [host [port]]      default: 127.0.0.1 4243
 */
#include <stdio.h>
#include <stdlib.h>
#include "WaveformGenerator.h"

int main(int argc, char *argv[])
{
    const char *host = argc > 1 ? argv[1] : "127.0.0.1";
    const char *port = argc > 2 ? argv[2] : "4243";

    struct IpdbgWaveformGeneratorHandle *wfg = IpdbgWaveformGenerator_new();
    if (!wfg)
    {
        printf("unable to allocate handle\n");
        return 1;
    }

    uint8_t *samples = NULL;
    int ret = IpdbgWaveformGenerator_open(wfg, host, port);
    if (ret != RET_OK)
        goto error;

    size_t dataWidth, addressWidth, maxSamples;
    bool running, doubleBuffer;
    if ((ret = IpdbgWaveformGenerator_getDataWidth(wfg, &dataWidth)) != RET_OK ||
        (ret = IpdbgWaveformGenerator_getAddressWidth(wfg, &addressWidth)) != RET_OK ||
        (ret = IpdbgWaveformGenerator_getMaxSamples(wfg, &maxSamples)) != RET_OK ||
        (ret = IpdbgWaveformGenerator_getStatus(wfg, &running, &doubleBuffer)) != RET_OK)
        goto error;

    printf("data width:    %zu bit\n", dataWidth);
    printf("address width: %zu bit (%zu samples)\n", addressWidth, maxSamples);
    printf("running:       %s\n", running ? "yes" : "no");
    printf("double buffer: %s\n", doubleBuffer ? "yes" : "no");

    /* sawtooth 0, 1, 2, ... wrapping at the data width, at most 256 samples */
    const size_t count = maxSamples < 256 ? maxSamples : 256;
    const size_t bytesPerSample = (dataWidth + 7) / 8;
    samples = (uint8_t *)calloc(count, bytesPerSample);
    if (!samples)
    {
        printf("unable to allocate samples\n");
        IpdbgWaveformGenerator_delete(wfg);
        return 1;
    }
    for (size_t s = 0; s < count; ++s)
    {
        uint64_t value = s;
        if (dataWidth < 64)
            value &= ((uint64_t)1 << dataWidth) - 1;
        for (size_t i = 0; i < bytesPerSample && i < 8; ++i)
            samples[s * bytesPerSample + i] = (uint8_t)(value >> (i * 8)); /* least significant byte first */
    }

    if ((ret = IpdbgWaveformGenerator_write(wfg, samples, count)) != RET_OK)
        goto error;
    printf("wrote %zu samples\n", count);

    if ((ret = IpdbgWaveformGenerator_start(wfg)) != RET_OK ||
        (ret = IpdbgWaveformGenerator_getStatus(wfg, &running, NULL)) != RET_OK)
        goto error;
    printf("running:       %s\n", running ? "yes" : "no");

    free(samples);
    IpdbgWaveformGenerator_delete(wfg);
    return 0;

error:
    printf("error: %s\n", IpdbgWaveformGenerator_getLastError(wfg));
    free(samples);
    IpdbgWaveformGenerator_delete(wfg);
    return 1;
}
