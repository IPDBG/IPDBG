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
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include <string.h>
#include <assert.h>


#include <urjtag/chain.h>

#include "jtaghost.h"

#include <urjtag/chain.h>
#include <urjtag/tap.h>
#include <urjtag/part.h> //urj_parts_t


#include <urjtag/data_register.h> // urj_part_data_register_define

#include <urjtag/part_instruction.h> // urj_part_instruction
#include <urjtag/tap_register.h> // urj_tap_register_set_value

#define URJ_STATUS_OK             0
#define URJ_STATUS_FAIL           1
#define URJ_STATUS_MUST_QUIT    (-2)

//int initSpartan3(urj_chain_t *chain);



int initSpartan3(urj_chain_t *chain);
int initiCE40(urj_chain_t *chain);

urj_chain_t *ipdbgJtagAllocChain(void)
{
    return urj_tap_chain_alloc();
}

int ipdbgJtagInit(urj_chain_t *chain)
{
    printf("ipdbgJtagInit\n");
    /// select cable
    char *Programmer_params[] = {"ft2232", "vid=0x0403", "pid=0x6010", 0};
    if(urj_tap_chain_connect(chain, Programmer_params[0], &(Programmer_params[1])) != 0)
    {
        printf("connect failed!\n");
        return -1;
    }

    urj_tap_reset(chain);


    /// detect devices in chain
    const int maxIrLen = 0;
    int numberOfParts = urj_tap_detect_parts(chain, "/usr/local/share/urjtag", maxIrLen);
    printf("number of parts detected = %d\n", numberOfParts);
    if ( numberOfParts == 0)
    {
        printf("detection of chain failed\n");
        return -2;
    }

    /// select active part in chain
    int active_part = 0;
    printf("select the active part\n");
    if (active_part >= chain->parts->len)
    {
        printf("selection of part not possible\n");
        return -3;
    }
    chain->active_part = active_part;
    printf("set the active part\n");

    urj_part_t *part = urj_tap_chain_active_part(chain);
    if (part == NULL)
    {
        printf("????\n");
        return -4;
    }


//    return initSpartan3(chain);
        return initiCE40(chain);
}

int initSpartan3(urj_chain_t *chain)
{
    printf("initSpartan3\n");
    urj_part_t *part = urj_tap_chain_active_part(chain);
    assert(part != NULL && "part must not be NULL");
    /// set instruction register length of part if database does not contain part?
    urj_part_instruction_length_set (part, 6);



    int user1register_register_length = 12; /// length of data register
    char *user1register_register_name = "USER1REGISTER";

    if(urj_part_data_register_define(part, user1register_register_name, user1register_register_length) != URJ_STATUS_OK)
    {
        printf("definition of register failed\n");
        return -8;
    }


    urj_part_instruction_t *instr = urj_part_instruction_define(part, "USER1", "000010", user1register_register_name);

    if(!instr)
    {
        printf("defining instruction failed\n");
        return -7;
    }


    /// load USER1 instruction
    urj_part_set_instruction(part, "USER1");
    urj_tap_chain_shift_instructions(chain);



    /// do datashift data shift
    urj_part_instruction_t *active_ir = part->active_instruction;
    if (active_ir == NULL)
    {
        printf("5 ?????\n");
        return -5;
    }
    urj_data_register_t *dreg = active_ir->data_register;
    if (dreg == NULL)
    {
        printf("6 ?????\n");
        return -6;
    }
    return 0;
}
int initiCE40(urj_chain_t *chain)
{
    printf("initiCE40\n");
    urj_part_t *part = urj_tap_chain_active_part(chain);
    assert(part != NULL && "part must not be NULL");
    /// set instruction register length of part if database does not contain part?
    urj_part_instruction_length_set (part, 8);
    printf("set instruction length\n");

    int user1register_register_length = 12; /// length of data register
    char *user1register_register_name = "USER1REGISTER";

    if(urj_part_data_register_define(part, user1register_register_name, user1register_register_length) != URJ_STATUS_OK)
    {
        printf("definition of register failed\n");
        return -8;
    }
    else
        printf("definition of register ok\n");

    urj_part_instruction_t *instr = urj_part_instruction_define(part, "USER1", "01010101", user1register_register_name);

    if(instr == URJ_STATUS_FAIL)
    {
        printf("defining instruction failed\n");
        return -7;
    }
    else
        printf("defining instruction ok\n");

    /// load USER1 instruction
    urj_part_set_instruction(part, "USER1");
    urj_tap_chain_shift_instructions(chain);



    /// do datashift data shift
    urj_part_instruction_t *active_ir = part->active_instruction;
    if (active_ir == NULL)
    {
        printf("5 ?????\n");
        return -5;
    }
    urj_data_register_t *dreg = active_ir->data_register;
    if (dreg == NULL)
    {
        printf("6 ?????\n");
        return -6;
    }
    return 0;
}


 //int ipdbgJTAGtransfer(urj_chain_t *chain, uint8_t *rxData, uint8_t*txData, int rx_len, int tx_len)
 int ipdbgJTAGtransfer(urj_chain_t *chain, uint16_t *upData, uint16_t downData)
 {
    urj_part_t *part = urj_tap_chain_active_part(chain);
    assert(part != NULL && "part must not be NULL");

    uint64_t dr_value_tx = downData;
    printf("jtagtransfer %04x\n", downData);
    urj_tap_register_set_value(part->active_instruction->data_register->in, dr_value_tx);
    urj_tap_chain_shift_data_registers(chain, 1);
    *upData = urj_tap_register_get_value (part->active_instruction->data_register->out);

    //urj_tap_chain_flush(chain);

    return JTAG_HOST_OK;
 }
void ipdbgJtagClose(urj_chain_t *chain)
{
    printf("ipdbgJtagClose\n");
    urj_tap_chain_disconnect(chain);
    urj_tap_chain_free(chain);
}
