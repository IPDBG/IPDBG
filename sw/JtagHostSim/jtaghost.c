/*
 * This file is part of the  ipdbg.org project.
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
#include <string.h>
#include <assert.h>

#include <stdio.h>
#include <stdlib.h>

#include "jtaghost.h"

uint16_t get_data_from_jtag_hub();
void set_data_to_jtag_hub(uint16_t);

int ipdbgJTAGtransfer(uint16_t *upData, uint16_t downData)
{
    set_data_to_jtag_hub(downData);
    *upData = get_data_from_jtag_hub();

    return JTAG_HOST_OK;
}
