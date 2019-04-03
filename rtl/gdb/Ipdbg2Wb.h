#ifndef IPDBG_2_WB_H_
#define IPDBG_2_WB_H_

#define TxReady         0x00000200   //empty
#define RxValid         0x00000100   //valid
#define BreakEn         0x00000001

struct ipdbg2WbRegister_st
{
    union{
        volatile unsigned int TxData;
        volatile unsigned int RxData;
    };
    volatile unsigned int ControlBits;
};

#define ipdbg2WbRegister  ((volatile struct ipdbg2WbRegister_st*)    0x80000000)

#endif
