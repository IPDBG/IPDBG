%include std_string.i
%include stdint.i
%inline %{
using namespace std;
%}

%module BusAccess
%{
  #include "../BusAccessCxx.h"
%}

%include "../BusAccessCxx.h"

%extend IpdbgBusAccess {
    %template(write)            write<uint64_t, uint64_t>;
    %template(read)             read<uint64_t, uint64_t>;
    %template(setMiscellaneous) setMiscellaneous<uint64_t>;
    %template(setStrobe)        setStrobe<uint64_t>;
}
