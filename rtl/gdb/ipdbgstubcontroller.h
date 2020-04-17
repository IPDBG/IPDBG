#ifndef IPDBG_GDB_CONTROLLER_H_
#define IPDBG_GDB_CONTROLLER_H_

#define TxReady         0x00000200   //empty
#define RxValid         0x00000100   //valid
#define BreakEn         0x00000001

struct IpdbgControllerRegister_st
{
    union{
        volatile unsigned int TxData;
        volatile unsigned int RxData;
    };
    volatile unsigned int ControlBits;
};

#endif
