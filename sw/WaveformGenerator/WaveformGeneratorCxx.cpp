#include "WaveformGeneratorCxx.h"
#include "WaveformGenerator.h"

#include <stdexcept>

IpdbgWaveformGenerator::IpdbgWaveformGenerator():
    handle_{IpdbgWaveformGenerator_new()}
{
    if (!handle_)
        throw std::runtime_error("unable to allocate waveform generator handle");
}

IpdbgWaveformGenerator::~IpdbgWaveformGenerator()
{
    IpdbgWaveformGenerator_delete(handle_);
}

std::string IpdbgWaveformGenerator::lastError()
{
    return IpdbgWaveformGenerator_getLastError(handle_);
}

void IpdbgWaveformGenerator::checkResult(int ret)
{
    if (ret != RET_OK)
        throw std::runtime_error(lastError());
}

void IpdbgWaveformGenerator::open(const std::string &ipAddrStr, const std::string &portNumberStr)
{
    checkResult(IpdbgWaveformGenerator_open(handle_, ipAddrStr.c_str(), portNumberStr.c_str()));
}

void IpdbgWaveformGenerator::close()
{
    checkResult(IpdbgWaveformGenerator_close(handle_));
}

bool IpdbgWaveformGenerator::isOpen()
{
    return IpdbgWaveformGenerator_isOpen(handle_);
}

size_t IpdbgWaveformGenerator::getDataWidth()
{
    size_t result;
    checkResult(IpdbgWaveformGenerator_getDataWidth(handle_, &result));
    return result;
}

size_t IpdbgWaveformGenerator::getAddressWidth()
{
    size_t result;
    checkResult(IpdbgWaveformGenerator_getAddressWidth(handle_, &result));
    return result;
}

size_t IpdbgWaveformGenerator::getMaxSamples()
{
    size_t result;
    checkResult(IpdbgWaveformGenerator_getMaxSamples(handle_, &result));
    return result;
}

bool IpdbgWaveformGenerator::isRunning()
{
    bool running;
    checkResult(IpdbgWaveformGenerator_getStatus(handle_, &running, nullptr));
    return running;
}

bool IpdbgWaveformGenerator::hasDoubleBuffer()
{
    bool doubleBuffer;
    checkResult(IpdbgWaveformGenerator_getStatus(handle_, nullptr, &doubleBuffer));
    return doubleBuffer;
}

void IpdbgWaveformGenerator::write(const std::vector<int64_t> &samples)
{
    const size_t bits = getDataWidth(); // throws if not connected
    if (bits > 64)
        throw std::runtime_error("data width " + std::to_string(bits) +
                                 " bit is wider than 64 bit, use the C API");

    if (samples.empty())
        throw std::runtime_error("no samples given");

    const size_t maxSamples = getMaxSamples();
    if (samples.size() > maxSamples)
        throw std::runtime_error(std::to_string(samples.size()) + " samples exceed the sample memory of " +
                                 std::to_string(maxSamples) + " samples");

    // valid range: -2^(bits-1) ... 2^bits-1; for 64 bit every int64_t fits
    const int64_t minValue = bits < 64 ? -(int64_t{1} << (bits - 1)) : INT64_MIN;
    const int64_t maxValue = bits < 63 ? (int64_t{1} << bits) - 1 : INT64_MAX;

    const size_t bytesPerSample = (bits + 7) / 8;
    std::vector<uint8_t> buffer(samples.size() * bytesPerSample);

    for (size_t s = 0; s < samples.size(); ++s)
    {
        const int64_t value = samples[s];
        if (value < minValue || value > maxValue)
            throw std::runtime_error("sample " + std::to_string(s) + " (" + std::to_string(value) +
                                     ") is outside the range " + std::to_string(minValue) + " ... " +
                                     std::to_string(maxValue) + " of the " + std::to_string(bits) +
                                     " bit data width");

        // two's complement, least significant byte first; the core ignores bits beyond the data width
        const uint64_t raw = static_cast<uint64_t>(value);
        for (size_t i = 0; i < bytesPerSample; ++i)
            buffer[s * bytesPerSample + i] = static_cast<uint8_t>(raw >> (i * 8));
    }

    checkResult(IpdbgWaveformGenerator_write(handle_, buffer.data(), samples.size()));
}

void IpdbgWaveformGenerator::start()
{
    checkResult(IpdbgWaveformGenerator_start(handle_));
}

void IpdbgWaveformGenerator::stop()
{
    checkResult(IpdbgWaveformGenerator_stop(handle_));
}

void IpdbgWaveformGenerator::oneShot()
{
    checkResult(IpdbgWaveformGenerator_oneShot(handle_));
}
