#include "BusAccess.h"

#include <limits>
#include <sstream>
#include <stdexcept>
#include <vector>

namespace IpdbgBusAccessDetail
{
    inline size_t bytesForBits(size_t bits)
    {
        return (bits + 7) / 8;
    }

    template <typename T>
    std::string toHex(T value)
    {
        std::ostringstream s;
        s << "0x" << std::hex << +value;
        return s.str();
    }

    // Converts value into a little endian byte buffer of ceil(bits / 8) bytes.
    // Throws if value has bits set beyond the field width.
    template <typename T>
    std::vector<uint8_t> toBytes(T value, size_t bits, const char *fieldName)
    {
        constexpr size_t typeBits = std::numeric_limits<T>::digits;

        if (bits < typeBits && (value >> bits) != 0)
            throw std::runtime_error(std::string(fieldName) + " " + toHex(value) +
                                     " exceeds the " + std::to_string(bits) + " bit field width");

        std::vector<uint8_t> buffer(bytesForBits(bits), 0);
        for (size_t i = 0; i < buffer.size() && i < sizeof(T); ++i)
            buffer[i] = static_cast<uint8_t>(value >> (i * 8));

        return buffer;
    }

    // Converts a little endian byte buffer of a field with the given width into T.
    // Throws if the field is wider than T.
    template <typename T>
    T fromBytes(const std::vector<uint8_t> &buffer, size_t bits, const char *fieldName)
    {
        constexpr size_t typeBits = std::numeric_limits<T>::digits;

        if (bits > typeBits)
            throw std::runtime_error(std::string(fieldName) + " (" + std::to_string(bits) +
                                     " bit) does not fit into a " + std::to_string(typeBits) + " bit type");

        T result{0};
        for (size_t i = 0; i < buffer.size(); ++i)
            result |= static_cast<T>(static_cast<T>(buffer[i]) << (i * 8));

        // mask unused bits of the most significant byte
        if (bits < typeBits)
            result &= static_cast<T>((static_cast<T>(1) << bits) - 1);

        return result;
    }
}

template <typename A, typename D>
void IpdbgBusAccess::write(A address, D data, bool locked)
{
    static_assert(std::is_unsigned_v<A>, "Address type must be unsigned");
    static_assert(std::is_unsigned_v<D>, "Data type must be unsigned");
    using namespace IpdbgBusAccessDetail;

    checkOpen();

    const size_t dataSize = getWriteDataSize();
    if (!dataSize)
        throw std::runtime_error("bus master has no write data");

    std::vector<uint8_t> addressBuffer = toBytes(address, getAddressSize(), "address");
    std::vector<uint8_t> dataBuffer = toBytes(data, dataSize, "write data");

    int ret = IpdbgBusAccess_write_ctrllock(handle_, addressBuffer.data(), dataBuffer.data(), locked);

    if (ret == RET_NAK)
        throw std::runtime_error("write to address " + toHex(address) + " answered with NAK");
    if (ret != RET_ACK)
        throw std::runtime_error("write to address " + toHex(address) + " failed: " + lastError());
}

template <typename A, typename D>
D IpdbgBusAccess::read(A address, bool locked)
{
    static_assert(std::is_unsigned_v<A>, "Address type must be unsigned");
    static_assert(std::is_unsigned_v<D>, "Data type must be unsigned");
    using namespace IpdbgBusAccessDetail;

    checkOpen();

    const size_t dataSize = getReadDataSize();
    if (!dataSize)
        throw std::runtime_error("bus master has no read data");

    std::vector<uint8_t> addressBuffer = toBytes(address, getAddressSize(), "address");
    std::vector<uint8_t> dataBuffer(bytesForBits(dataSize), 0);

    // check the type before accessing the bus: reads may have side effects
    constexpr size_t typeBits = std::numeric_limits<D>::digits;
    if (dataSize > typeBits)
        throw std::runtime_error("read data (" + std::to_string(dataSize) +
                                 " bit) does not fit into a " + std::to_string(typeBits) + " bit type");

    int ret = IpdbgBusAccess_read_ctrllock(handle_, addressBuffer.data(), dataBuffer.data(), locked);

    if (ret == RET_NAK)
        throw std::runtime_error("read from address " + toHex(address) + " answered with NAK");
    if (ret != RET_ACK)
        throw std::runtime_error("read from address " + toHex(address) + " failed: " + lastError());

    return fromBytes<D>(dataBuffer, dataSize, "read data");
}

template <typename M>
void IpdbgBusAccess::setMiscellaneous(M value)
{
    static_assert(std::is_unsigned_v<M>, "Misc type must be unsigned");
    using namespace IpdbgBusAccessDetail;

    checkOpen();

    const size_t sz = getMiscSize();
    std::vector<uint8_t> buffer = toBytes(value, sz, "misc value");
    if (!sz)
        return;

    if (IpdbgBusAccess_setMiscellaneous(handle_, buffer.data()) != RET_OK)
        throw std::runtime_error("setting misc signals failed: " + lastError());
}

template <typename S>
void IpdbgBusAccess::setStrobe(S value)
{
    static_assert(std::is_unsigned_v<S>, "Strobe type must be unsigned");
    using namespace IpdbgBusAccessDetail;

    checkOpen();

    const size_t sz = getStrobeSize();
    std::vector<uint8_t> buffer = toBytes(value, sz, "strobe value");
    if (!sz)
        return;

    if (IpdbgBusAccess_setStrobe(handle_, buffer.data()) != RET_OK)
        throw std::runtime_error("setting strobe failed: " + lastError());
}

template <typename A, typename D>
void IpdbgBusAccess::read_modify_write(A address, std::function<D(D)> modifyFunction)
{
    static_assert(std::is_unsigned_v<A>, "Address type must be unsigned");
    static_assert(std::is_unsigned_v<D>, "Data type must be unsigned");

    D val = read<A, D>(address, true);
    if (modifyFunction)
        val = modifyFunction(val);
    write<A, D>(address, val, false); // unlocked write releases the lock
}
