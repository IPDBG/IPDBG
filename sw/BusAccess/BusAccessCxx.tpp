#include "BusAccess.h"

template <typename A, typename D>
void IpdbgBusAccess::write(A address, D data, bool locked)
{
    static_assert( std::is_unsigned_v<A> == true, "Address type must be unsigned");
    static_assert( std::is_unsigned_v<D> == true, "Data type must be unsigned");

    if (!handle_ || !isOpen())
        throw -1;

    size_t addressSize = getAddressSize();
    size_t addressBufferSize = addressSize;
    if (!addressSize)
        addressBufferSize = 1;

    size_t dataSize = getWriteDataSize();
    if (!dataSize)
        throw -1;

    uint8_t dataBuffer[dataSize];
    uint8_t addressBuffer[addressBufferSize];

    for (size_t i = 0 ; i < addressSize; ++i)
    {
        addressBuffer[i] = address & 0xff;
        address >>= 8; //unsigned will shift in '0's
    }

    for (size_t i = 0 ; i < dataSize; ++i)
    {
        dataBuffer[i] = data & 0xff;
        data >>= 8;
    }

    int ret = IpdbgBusAccess_write_ctrllock(handle_, addressBuffer, dataBuffer, locked);

    if (ret != RET_ACK)
        throw -1;
}

template <typename A, typename D>
D IpdbgBusAccess::read(A address, bool locked)
{
    static_assert( std::is_unsigned_v<A> == true, "Address type must be unsigned");
    static_assert( std::is_unsigned_v<D> == true, "Data type must be unsigned");

    if (!handle_ || !isOpen())
        throw -1;

    size_t addressSize = getAddressSize();
    size_t addressBufferSize = addressSize;
    if (!addressSize)
        addressBufferSize = 1;

    size_t dataSize = getReadDataSize();
    if (!dataSize)
        throw -1;

    uint8_t dataBuffer[dataSize];
    uint8_t addressBuffer[addressBufferSize];

    for (size_t i = 0 ; i < addressSize; ++i)
    {
        addressBuffer[i] = address & 0xff;
        address >>= 8; //unsigned will shift in '0's
    }

    int ret = IpdbgBusAccess_read_ctrllock(handle_, addressBuffer, dataBuffer, locked);

    if (ret != RET_ACK)
        throw -1;

    D result{0};
    for (size_t i = 0; i < dataSize && i < sizeof(D); ++i)
        result |= (dataBuffer[i] << i*8);

    return result;
}

template <typename M>
void IpdbgBusAccess::setMiscellaneous(M value)
{
    static_assert( std::is_unsigned_v<M> == true, "Misc type must be unsigned");

    if (!handle_ || !isOpen())
        throw -1;

    size_t sz = getMiscSize();
    if (!sz)
        return;

    uint8_t buffer[sz];

    for (size_t i = 0 ; i < sz; ++i)
    {
        buffer[i] = value & 0xff;
        value >>= 8; //unsigned will shift in '0's
    }

    int ret = IpdbgBusAccess_setMiscellaneous(handle_, buffer);

    if (ret != RET_OK)
        throw -1;
}

template <typename S>
void IpdbgBusAccess::setStrobe(S value)
{
    static_assert( std::is_unsigned_v<S> == true, "Strobe type must be unsigned");

    if (!handle_ || !isOpen())
        throw -1;

    size_t sz = getStrobeSize();
    if (!sz)
        return;

    uint8_t buffer[sz];

    for (size_t i = 0 ; i < sz; ++i)
    {
        buffer[i] = value & 0xff;
        value >>= 8; //unsigned will shift in '0's
    }

    int ret = IpdbgBusAccess_setStrobe(handle_, buffer);

    if (ret != RET_OK)
        throw -1;
}

template <typename A, typename D>
void IpdbgBusAccess::read_modify_write(A address, std::function<D(D)> modifyFunction)
{
    static_assert( std::is_unsigned_v<A> == true, "Address type must be unsigned");
    static_assert( std::is_unsigned_v<D> == true, "Data type must be unsigned");

    D val = this->read(address, true);
    val = modifyFunction(val);
    this->write(address, false);
}
