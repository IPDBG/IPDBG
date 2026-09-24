#include "BusAccessCxx.h"
#include "BusAccess.h"

#include <stdexcept>

IpdbgBusAccess::IpdbgBusAccess():
    handle_{IpdbgBusAccess_new()}
{
    if (!handle_)
        throw std::runtime_error("unable to allocate bus access handle");
}

IpdbgBusAccess::~IpdbgBusAccess()
{
    IpdbgBusAccess_delete(handle_);
}

std::string IpdbgBusAccess::lastError()
{
    return IpdbgBusAccess_getLastError(handle_);
}

void IpdbgBusAccess::checkOpen()
{
    if (!isOpen())
        throw std::runtime_error("not connected");
}

void IpdbgBusAccess::open(const std::string &ipAddrStr, const std::string &portNumberStr)
{
    if (IpdbgBusAccess_open(handle_, ipAddrStr.c_str(), portNumberStr.c_str()) != RET_OK)
        throw std::runtime_error(lastError());
}

void IpdbgBusAccess::close()
{
    if (IpdbgBusAccess_close(handle_) != RET_OK)
        throw std::runtime_error(lastError());
}

bool IpdbgBusAccess::isOpen()
{
    return IpdbgBusAccess_isOpen(handle_);
}

namespace
{
    template <enum BusAccessField Field>
    size_t getFieldSize(struct IpdbgBusAccessHandle *handle)
    {
        size_t result;
        if (IpdbgBusAccess_getFieldSize(handle, Field, &result) != RET_OK)
            throw std::runtime_error(IpdbgBusAccess_getLastError(handle));
        return result;
    }

    void checkHelperResult(struct IpdbgBusAccessHandle *handle, int ret)
    {
        if (ret != RET_OK)
            throw std::runtime_error(IpdbgBusAccess_getLastError(handle));
    }
}

size_t IpdbgBusAccess::getAddressSize()
{
    return getFieldSize<ADDRESS>(handle_);
}

size_t IpdbgBusAccess::getReadDataSize()
{
    return getFieldSize<READ_DATA>(handle_);
}

size_t IpdbgBusAccess::getWriteDataSize()
{
    return getFieldSize<WRITE_DATA>(handle_);
}

size_t IpdbgBusAccess::getStrobeSize()
{
    return getFieldSize<STROBE>(handle_);
}

size_t IpdbgBusAccess::getMiscSize()
{
    return getFieldSize<MISC>(handle_);
}

void IpdbgBusAccess::setAxi4lAxprot(uint8_t arprot, uint8_t awprot)
{
    checkHelperResult(handle_, IpdbgAxi4lAccess_setAxprot(handle_, arprot, awprot));
}

void IpdbgBusAccess::setApbPprot(uint8_t pprot)
{
    checkHelperResult(handle_, IpdbgApbAccess_setPprot(handle_, pprot));
}

void IpdbgBusAccess::setAvalonDebugAccess(uint8_t debug)
{
    checkHelperResult(handle_, IpdbgAvalonAccess_setDebugAccess(handle_, debug));
}

void IpdbgBusAccess::setAhbHprotHsize(uint8_t hprot, uint8_t hsize)
{
    checkHelperResult(handle_, IpdbgAhbAccess_setHprotHsize(handle_, hprot, hsize));
}

void IpdbgBusAccess::setDtmResets(bool reset, bool hardreset)
{
    checkHelperResult(handle_, IpdbgDtm_setResets(handle_, reset, hardreset));
}
