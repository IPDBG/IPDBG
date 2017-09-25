/*
 * This file is part of the ipdbg.org project.
 *
 * Copyright (C) 2016 ek <ek>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
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

#include <stdint.h>

#define JTAG_HOST_OK 0
#define JTAG_HOST_ERR -1


int ipdbgJTAGtransfer(uint16_t *upData, uint16_t downData);

#ifdef __cplusplus
}
#endif

#endif
