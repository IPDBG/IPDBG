#include "BusAccessCxx.h"
#include "BusAccess.h"


IpdbgBusAccess::IpdbgBusAccess():
    handle_{IpdbgBusAccess_new()}
{}

IpdbgBusAccess::~IpdbgBusAccess()
{
    if (!handle_)
        return;

    IpdbgBusAccess_delete(handle_);
}

void IpdbgBusAccess::open(const std::string &ipAddrStr, const std::string &portNumberStr)
{
    int ret = IpdbgBusAccess_open(handle_, ipAddrStr.c_str(), portNumberStr.c_str());
    if (ret != RET_OK)
        throw -1;
}

void IpdbgBusAccess::close()
{
    int ret = IpdbgBusAccess_close(handle_);
    if (ret != RET_OK)
        throw -1;
}

bool IpdbgBusAccess::isOpen()
{
    return IpdbgBusAccess_isOpen(handle_);
}

template <enum BusAccessField Field>
size_t getFieldSize(struct IpdbgBusAccessHandle *handle)
{
    size_t result;
    int ret = IpdbgBusAccess_getFieldSize(handle, Field, &result);
    if (ret != RET_OK)
        throw -1;
    return result;
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
    int ret = IpdbgAxi4lAccess_setAxprot(handle_, arprot, awprot);
    if (ret != RET_OK)
        throw -1;
}

void IpdbgBusAccess::setApbPprot(uint8_t pprot)
{
    int ret = IpdbgApbAccess_setPprot(handle_, pprot);
    if (ret != RET_OK)
        throw -1;
}

void IpdbgBusAccess::setAvalonDebugAccess(uint8_t debug)
{
    int ret = IpdbgAvalonAccess_setDebugAccess(handle_, debug);
    if (ret != RET_OK)
        throw -1;
}

void IpdbgBusAccess::setAhbHprotHsize(uint8_t hprot, uint8_t hsize)
{
    int ret = IpdbgAhbAccess_setHprotHsize(handle_, hprot, hsize);
    if (ret != RET_OK)
        throw -1;
}

void IpdbgBusAccess::setDtmResets(bool reset, bool hardreset)
{
    int ret = IpdbgDtm_setResets(handle_, reset, hardreset);
    if (ret != RET_OK)
        throw -1;
}
