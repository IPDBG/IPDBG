#ifndef JTAG_HOST_LOOP
#define JTAG_HOST_LOOP

extern "C" int jtagHostLoop();
extern "C" void set_data_to_jtag_host(uint32_t data);
extern "C" uint32_t get_data_from_jtag_host(uint32_t unused);

#endif
