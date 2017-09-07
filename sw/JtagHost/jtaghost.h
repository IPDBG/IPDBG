/*
 * This file is part of the libsigrok project.
 *
 * Copyright (C) 2016 ek <ek>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANYWARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#ifndef IPDBG_JTAG_HOST_H
#define IPDBG_JTAG_HOST_H

#ifdef __cplusplus
extern "C"
{
#endif



#include <urjtag/chain.h>

#include <stdint.h>
//#include <libsigrok/libsigrok.h>
//#include "libsigrok-internal.h"

#define LOG_PREFIX "ipdbg-la"

#define JTAG_HOST_OK 0
#define JTAG_HOST_ERR -1




urj_chain_t *ipdbgJtagAllocChain(void);
int ipdbgJtagInit(urj_chain_t *chain, int apart);
int ipdbgJTAGtransfer(urj_chain_t *chain, uint16_t *upData, uint16_t downData);
void ipdbgJtagClose(urj_chain_t *chain);


#endif

#ifdef __cplusplus
}
#endif
