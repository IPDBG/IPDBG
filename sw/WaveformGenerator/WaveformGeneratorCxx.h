#ifndef WAVEFORMGENERATOR_HPP_INCLUDED
#define WAVEFORMGENERATOR_HPP_INCLUDED

#include "WaveformGenerator.h" // API: export/import of the member functions

#include <cstdint>
#include <cstddef>
#include <string>
#include <vector>

class IpdbgWaveformGenerator
{
public:
    API IpdbgWaveformGenerator();
    API virtual ~IpdbgWaveformGenerator();

    // owns a C handle: not copyable
    IpdbgWaveformGenerator(const IpdbgWaveformGenerator &) = delete;
    IpdbgWaveformGenerator &operator=(const IpdbgWaveformGenerator &) = delete;

    API void open(const std::string &ipAddrStr, const std::string &portNumberStr);
    API void close();
    API bool isOpen();

    // widths in bits
    API size_t getDataWidth();
    API size_t getAddressWidth();
    // size of the sample memory
    API size_t getMaxSamples();

    API bool isRunning();
    API bool hasDoubleBuffer();

    // Each sample must be in the range -2^(N-1) ... 2^N-1 (N = data width, up to 64 bit).
    // Negative values are sent as two's complement.
    API void write(const std::vector<int64_t> &samples);

    API void start();
    API void stop();
    API void oneShot();

private:
    void checkResult(int ret);
    std::string lastError(); // error message of the C library

    struct IpdbgWaveformGeneratorHandle *handle_;
};

#endif // WAVEFORMGENERATOR_HPP_INCLUDED
