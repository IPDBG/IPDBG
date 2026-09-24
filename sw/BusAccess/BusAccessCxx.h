#ifndef BUSACCESS_HPP_INCLUDED
#define BUSACCESS_HPP_INCLUDED

#include <cstdint>
#include <cstddef>
#include <string>
#include <type_traits>
#include <functional>

class IpdbgBusAccess
{
public:
    IpdbgBusAccess();
    virtual ~IpdbgBusAccess();

    // owns a C handle: not copyable
    IpdbgBusAccess(const IpdbgBusAccess &) = delete;
    IpdbgBusAccess &operator=(const IpdbgBusAccess &) = delete;

    void open(const std::string &ipAddrStr, const std::string &portNumberStr);
    void close();
    bool isOpen();

    // all sizes in bits
    size_t getAddressSize();
    size_t getReadDataSize();
    size_t getWriteDataSize();
    size_t getStrobeSize();
    size_t getMiscSize();

    void setAxi4lAxprot(uint8_t arprot, uint8_t awprot);
    void setApbPprot(uint8_t pprot);
    void setAvalonDebugAccess(uint8_t debug);
    void setAhbHprotHsize(uint8_t hprot, uint8_t hsize);
    void setDtmResets(bool reset, bool hardreset);

    template <typename A, typename D>
    void write(A address, D data, bool locked = false);

    template <typename A, typename D>
    D read(A address, bool locked = false);

    template <typename M>
    void setMiscellaneous(M value);

    template <typename S>
    void setStrobe(S value);

    template <typename A, typename D>
    void read_modify_write(A address, std::function<D(D)> modifyFunction);

private:
    void checkOpen();
    std::string lastError(); // error message of the C library

    struct IpdbgBusAccessHandle *handle_;
};

#include "BusAccessCxx.tpp"

#endif // BUSACCESS_HPP_INCLUDED
