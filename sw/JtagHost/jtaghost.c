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
#include <urjtag/part.h>                //urj_parts_t


#include <urjtag/data_register.h>       // urj_part_data_register_define

#include <urjtag/part_instruction.h>    // urj_part_instruction
#include <urjtag/tap_register.h>        // urj_tap_register_set_value

#define URJ_STATUS_OK             0
#define URJ_STATUS_FAIL           1
#define URJ_STATUS_MUST_QUIT    (-2)

#include <stdio.h>
#include <stdlib.h>

//int initSpartan3(urj_chain_t *chain);



int initSpartan3(urj_chain_t *chain);
int initiCE40(urj_chain_t *chain);
int initEcp2(urj_chain_t *chain);
int initSpartan6(urj_chain_t *chain);
int init7Series(urj_chain_t *chain);

urj_chain_t *ipdbgJtagAllocChain(void)
{
    return urj_tap_chain_alloc();
}

int ipdbgJtagInit(urj_chain_t *chain, int apart)
{

    int active_part = apart;
    if (active_part >= chain->parts->len)
    {
        printf("selection of part not possible\n");
        return -3;
    }

    chain->active_part = active_part;

    urj_part_t *part = urj_tap_chain_active_part(chain);
    if (part == NULL)
    {
        printf("????\n");
        return -4;
    }

    if ( strcmp(part->manufacturer, "Xilinx") == 0)
    {
        if(strcmp(part->part, "xc3s50") == 0 ||
           strcmp(part->part, "xc3s200") == 0 ||
           strcmp(part->part, "xc3s400") == 0 ||
           strcmp(part->part, "xc3s1000") == 0 ||
           strcmp(part->part, "xc3s1500") == 0 ||
           strcmp(part->part, "xc3s2000") == 0 ||
           strcmp(part->part, "xc3s4000") == 0 ||
           strcmp(part->part, "xc3s5000") == 0 ||
           strcmp(part->part, "xc3s1600e") == 0 ||
           strcmp(part->part, "xc3s50a") == 0 ||
           strcmp(part->part, "xc3s200a") == 0 ||
           strcmp(part->part, "xc3s400a") == 0 ||
           strcmp(part->part, "xc3s700a") == 0 ||
           strcmp(part->part, "xc3s1400a") == 0 ||
           strcmp(part->part, "xc3s100e_die") == 0 ||
           strcmp(part->part, "xc3s500e_fg320") == 0 ||
           strcmp(part->part, "xc3s1200e_fg320") == 0)
            return initSpartan3(chain);
        else if(strcmp(part->part, "xc6slx4") == 0 ||
                strcmp(part->part, "xc6slx9") == 0 ||
                strcmp(part->part, "xc6slx16") == 0 ||
                strcmp(part->part, "xc6slx25") == 0 ||
                strcmp(part->part, "xc6slx25t") == 0 ||
                strcmp(part->part, "xc6slx45") == 0 ||
                strcmp(part->part, "xc6slx45t") == 0 ||
                strcmp(part->part, "xc6slx75") == 0 ||
                strcmp(part->part, "xc6slx75t") == 0 ||
                strcmp(part->part, "xc6slx100") == 0 ||
                strcmp(part->part, "xc6slx100t") == 0 ||
                strcmp(part->part, "xc6slx150") == 0 ||
                strcmp(part->part, "xc6slx150t") == 0)
            return initSpartan6(chain);

        else if(strcmp(part->part, "xc7a35t") == 0 ||
                strcmp(part->part, "xc7a50t") == 0 ||
                strcmp(part->part, "xc7a75t") == 0 ||
                strcmp(part->part, "xc7a100t") == 0 ||
                strcmp(part->part, "xc7a200t") == 0 ||

                strcmp(part->part, "xc7k325t") == 0 )
            return init7Series(chain);
        else
        {
            printf("xilinx family not supported yet");
            return -1;
        }
    }
    else if ( strcmp(part->manufacturer, "Lattice Semiconductors") == 0)
    {
        if(strcmp(part->part, "LFE2-12E") == 0)
            return initEcp2(chain);
    }
    else if ( strcmp(part->manufacturer, "ipdbg.org") == 0)
    {
        return initiCE40(chain);
    }
    return -1;
}

int init7Series(urj_chain_t *chain)
{
    printf("init7Series\n");

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

int initEcp2(urj_chain_t *chain)
{
    printf("initEcp2\n");
    urj_part_t *part = urj_tap_chain_active_part(chain);
    assert(part != NULL && "part must not be NULL");
    /// set instruction register length of part if database does not contain part?
    urj_part_instruction_length_set (part, 8);



    int user1register_register_length = 12; /// length of data register
    char *user1register_register_name = "USER1REGISTER";

    if(urj_part_data_register_define(part, user1register_register_name, user1register_register_length) != URJ_STATUS_OK)
    {
        printf("definition of register failed\n");
        return -8;
    }


    urj_part_instruction_t *instr = urj_part_instruction_define(part, "USER1", "00110010", user1register_register_name);

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

int initSpartan6(urj_chain_t *chain)
{
    printf("initSpartan6\n");
    printf("not tested\n");
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

    if(!instr)
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

int ipdbgJTAGtransfer(urj_chain_t *chain, uint16_t *upData, uint16_t downData)
{
    urj_part_t *part = urj_tap_chain_active_part(chain);
    assert(part != NULL && "part must not be NULL");

    uint64_t dr_value_tx = downData;
    printf("jtagtransfer %04x\n", downData);
    printf("jtagtransfer %04x\n", upData);
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

