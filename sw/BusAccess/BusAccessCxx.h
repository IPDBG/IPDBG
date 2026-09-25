#ifndef BUSACCESS_HPP_INCLUDED
#define BUSACCESS_HPP_INCLUDED

#include "BusAccess.h" // API: export/import of the member functions

#include <cstdint>
#include <cstddef>
#include <string>
#include <type_traits>
#include <functional>

class IpdbgBusAccess
{
public:
    API IpdbgBusAccess();
    API virtual ~IpdbgBusAccess();

    // owns a C handle: not copyable
    IpdbgBusAccess(const IpdbgBusAccess &) = delete;
    IpdbgBusAccess &operator=(const IpdbgBusAccess &) = delete;

    API void open(const std::string &ipAddrStr, const std::string &portNumberStr);
    API void close();
    API bool isOpen();

    // all sizes in bits
    API size_t getAddressSize();
    API size_t getReadDataSize();
    API size_t getWriteDataSize();
    API size_t getStrobeSize();
    API size_t getMiscSize();

    API void setAxi4lAxprot(uint8_t arprot, uint8_t awprot);
    API void setApbPprot(uint8_t pprot);
    API void setAvalonDebugAccess(uint8_t debug);
    API void setAhbHprotHsize(uint8_t hprot, uint8_t hsize);
    API void setDtmResets(bool reset, bool hardreset);

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
    // exported: used by the member templates in BusAccessCxx.tpp
    API void checkOpen();
    API std::string lastError(); // error message of the C library

    struct IpdbgBusAccessHandle *handle_;
};

#include "BusAccessCxx.tpp"

#endif // BUSACCESS_HPP_INCLUDED
