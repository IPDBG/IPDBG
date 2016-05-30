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

#include <config.h>
#include "protocol.h"
#include <urjtag/chain.h>

#include <urjtag/chain.h>
#include <urjtag/tap.h>
#include <urjtag/part.h> //urj_parts_t


#include <urjtag/data_register.h> // urj_part_data_register_define

#include <urjtag/part_instruction.h> // urj_part_instruction
#include <urjtag/tap_register.h> // urj_tap_register_set_value

#include "jtaghost.h"


#define Start                      0xFE
#define reset                      0xAB
#define IDBG                       0xBB
#define Escape                     0x55




/* Command opcodes */
#define set_trigger                0x00
#define Trigger                    0xF0
#define LA                         0x0F
#define Masks                      0xF1
#define Mask                       0xF3
#define Value                      0xF7
#define Last_Masks                 0xF9
#define Mask_last                  0xFB
#define Value_last                 0xFF
#define delay                      0x1F
#define K_Mauslesen                0xAA

#define IPDBG_LA_VALID_MASK        0xC00


//SP_PRIV int initSpartan3(urj_chain_t *chain);
SR_PRIV int sendEscaping(urj_chain_t *chain, char *dataToSend, int length);
//SR_PRIV int initSpartan3(urj_chain_t *chain);

SR_PRIV int ipdbg_convert_trigger(const struct sr_dev_inst *sdi)
{
    struct ipdbgla_dev_context *devc;
    struct sr_trigger *trigger;
    struct sr_trigger_stage *stage;
    struct sr_trigger_match *match;
    const GSList *l, *m;

    devc = sdi->priv;

    devc->num_stages = 0;
    devc->num_transfers = 0;
    devc->raw_sample_buf = NULL; /// name convert_trigger to init acquisition...
    for (int i = 0; i < devc->DATA_WIDTH_BYTES; i++) // Hier werden die Trigger-Variabeln 0 gesetzt!
    {
        devc->trigger_mask[i] = ~0;
        devc->trigger_value[i] = 0;
        devc->trigger_mask_last [i] = ~0;
        devc->trigger_value_last[i]= 0;
    }


    devc->trigger_value[0] = 0x02;
    devc->trigger_value_last[0] = 0x01;
    devc->trigger_mask[0] = 0xFF;
    devc->trigger_mask_last[0] = 0xFF;

    if (!(trigger = sr_session_trigger_get(sdi->session)))
        return SR_OK;

    devc->num_stages = g_slist_length(trigger->stages);
    if (devc->num_stages != devc->DATA_WIDTH_BYTES) {
        sr_err("This device only supports %d trigger stages.",
                devc->DATA_WIDTH_BYTES);
        return SR_ERR;
    }

    for (l = trigger->stages; l; l = l->next) {
        stage = l->data;
        for (m = stage->matches; m; m = m->next) {
            match = m->data;
            unsigned int byteIndex = (match->channel->index) /8;
            unsigned char matchPattern = 1 << (match->channel->index - 8* byteIndex);

            if (!match->channel->enabled)
                /* Ignore disabled channels with a trigger. */
                continue;
            devc->trigger_mask[byteIndex] &= ~matchPattern;
            if (match->match == SR_TRIGGER_ONE )
            {
                devc->trigger_value[byteIndex] |= matchPattern;
                devc->trigger_mask[byteIndex] &= ~matchPattern;

            }
            else if (match->match == SR_TRIGGER_ZERO)
            {
                devc->trigger_mask[byteIndex] &= ~matchPattern;
            }
            else if ( match->match == SR_TRIGGER_RISING)
            {
                devc->trigger_value[byteIndex] |= matchPattern;
                devc->trigger_mask[byteIndex] &= ~matchPattern;
                devc->trigger_mask_last[byteIndex] &= ~matchPattern;

            }
            else if (match->match == SR_TRIGGER_FALLING )
            {

                devc->trigger_value[byteIndex] &= ~matchPattern;
                devc->trigger_mask[byteIndex] &= ~matchPattern;
                devc->trigger_value_last[byteIndex] |= matchPattern;
                devc->trigger_mask_last[byteIndex] &= ~matchPattern;
            }

        }
    }



    return SR_OK;
}
SR_PRIV int ipdbg_receive_data(int fd, int revents, void *cb_data)
{

    const struct sr_dev_inst *sdi;
    struct ipdbgla_dev_context *devc;

    (void)fd;
	(void)revents;

    if (!(sdi = cb_data))
    {
        return TRUE;
    }

    if (!(devc = sdi->priv))
    {
        return TRUE;
    }

    urj_chain_t *chain = sdi->conn;
    struct sr_datafeed_packet packet;
    struct sr_datafeed_logic logic;



    /*sr_warn("---");
    if (devc->num_transfers == 0 && revents == 0)
    { //
        sr_warn("warten auf Eingangsdaten");
        // Ignore timeouts as long as we haven't received anything
        return TRUE;
    }*/

    if (!devc->raw_sample_buf)
    {
        //sr_warn("allocating buffer");
        devc->raw_sample_buf = g_try_malloc(devc->limit_samples*devc->DATA_WIDTH_BYTES);

        if (!devc->raw_sample_buf) {
            sr_warn("Sample buffer malloc failed.");
            return FALSE;
        }

    }


    if (devc->num_transfers < devc->limit_samples*devc->DATA_WIDTH_BYTES)
    {
        unsigned char byte;

        if (ipdbgJtagRead(chain, &byte, 1, IPDBG_LA_VALID_MASK) == 1)
        {
            devc->raw_sample_buf[devc->num_transfers++] = byte;
        }

    }
    else
    {

        sr_dbg("Received %d bytes.", devc->num_transfers);

        if (devc->delay_value > 0) {
            /* There are pre-trigger samples, send those first. */
            packet.type = SR_DF_LOGIC;
            packet.payload = &logic;
            //logic.length = devc->delay_value-1;
            logic.length = devc->delay_value*devc->DATA_WIDTH_BYTES;
            logic.unitsize = devc->DATA_WIDTH_BYTES;
            logic.data = devc->raw_sample_buf;
            sr_session_send(cb_data, &packet);
        }

        /* Send the trigger. */
        packet.type = SR_DF_TRIGGER;
        sr_session_send(cb_data, &packet);

        /* Send post-trigger samples. */
        packet.type = SR_DF_LOGIC;
        packet.payload = &logic;
        //logic.length = devc->limit_samples - devc->delay_value+1;
        logic.length = (devc->limit_samples - devc->delay_value)*devc->DATA_WIDTH_BYTES;
        logic.unitsize = devc->DATA_WIDTH_BYTES;
        logic.data = devc->raw_sample_buf + devc->delay_value*devc->DATA_WIDTH_BYTES;
        //logic.data = devc->raw_sample_buf + devc->delay_value-1;
        sr_session_send(cb_data, &packet);

        g_free(devc->raw_sample_buf);
        devc->raw_sample_buf = NULL;

        //serial_flush(serial);
        ipdbg_abort_acquisition(sdi);//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    }

    return TRUE;
}
SR_PRIV int sendDelay( struct ipdbgla_dev_context *devc, urj_chain_t *chain)
{
    //sr_warn("delay");

    int maxSample;

    maxSample = 0x1 << (devc->ADDR_WIDTH);

    devc->delay_value = (maxSample/100.0) * devc->capture_ratio;
    uint8_t Befehl[1];
    Befehl[0] = LA;
    ipdbgJtagWrite(chain, Befehl, 1, IPDBG_LA_VALID_MASK);
    Befehl[0] = delay;
    ipdbgJtagWrite(chain, Befehl, 1, IPDBG_LA_VALID_MASK);

    //sr_warn("delay 2");


    char buf[4] = { devc->delay_value        & 0x000000ff,
                   (devc->delay_value >>  8) & 0x000000ff,
                   (devc->delay_value >> 16) & 0x000000ff,
                   (devc->delay_value >> 24) & 0x000000ff};

    //sendEscaping(serial, buf, devc->ADDR_WIDTH_BYTES);
    sendEscaping(chain, buf, devc->ADDR_WIDTH_BYTES);

    //sr_warn("send delay_value: 0x%.2x", devc->delay_value);

    return JTAG_HOST_OK;
}
SR_PRIV int sendTrigger(struct ipdbgla_dev_context *devc, urj_chain_t *chain)
{
    /////////////////////////////////////////////Mask////////////////////////////////////////////////////////////
    uint8_t buf[1];
    buf[0] = Trigger;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);
    buf[0] = Masks;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);
    buf[0] = Mask;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);

    sendEscaping(chain, devc->trigger_mask, devc->DATA_WIDTH_BYTES);

    //sr_warn("send trigger_mask: %x", devc->trigger_mask[0]);


     /////////////////////////////////////////////Value////////////////////////////////////////////////////////////
    buf[0]= Trigger;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);
    buf[0] = Masks;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);
    buf[0] = Value;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);


    sendEscaping(chain, devc->trigger_value, devc->DATA_WIDTH_BYTES);

    //sr_warn("send trigger_value: 0x%.2x", devc->trigger_value[0]);


    /////////////////////////////////////////////Mask_last////////////////////////////////////////////////////////////
    buf[0] = Trigger;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);
    buf[0] = Last_Masks;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);
    buf[0] = Mask_last;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);


    sendEscaping(chain, devc->trigger_mask_last, devc->DATA_WIDTH_BYTES);


    //sr_warn("send trigger_mask_last: 0x%.2x", devc->trigger_mask_last[0]);


    /////////////////////////////////////////////Value_last////////////////////////////////////////////////////////////
    buf[0] = Trigger;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);
    buf[0]= Last_Masks;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);
    buf[0]= Value_last;
    ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK);


    sendEscaping(chain, devc->trigger_value_last, devc->DATA_WIDTH_BYTES);


    //sr_warn("send trigger_value_last: 0x%.2x", devc->trigger_value_last[0]);



    return JTAG_HOST_OK;
}
SR_PRIV int sendEscaping(urj_chain_t *chain, char *dataToSend, int length)
{

    while(length--)
    {
        uint8_t payload = *dataToSend++;
        //sr_warn("payload %d", payload);

        //sr_warn("send really");

        if ( payload == (uint8_t)reset )
        {
            uint8_t escapeSymbol = Escape;
            sr_warn("Escape");

            if(ipdbgJtagWrite(chain, &escapeSymbol, 1, IPDBG_LA_VALID_MASK) != JTAG_HOST_OK)
                sr_warn("can't send escape");


        }

        if ( payload == (char)Escape )
        {
            uint8_t escapeSymbol = Escape;
            sr_warn("Escape");

            if(ipdbgJtagWrite(chain, &escapeSymbol, 1, IPDBG_LA_VALID_MASK) != JTAG_HOST_OK)
                sr_warn("can't send escape");
        }

        if (ipdbgJtagWrite(chain, &payload, 1, IPDBG_LA_VALID_MASK) != JTAG_HOST_OK)
        {
            sr_warn("Can't send data");
        }
         //sr_warn("length %d", length);

    }
    return JTAG_HOST_OK;
}
SR_PRIV void getAddrWidthAndDataWidth(urj_chain_t *chain, struct ipdbgla_dev_context *devc)
{
    //printf("getAddrAndDataWidth\n");
    uint8_t buf[8];
    uint8_t auslesen[1];
    auslesen[0]= K_Mauslesen;

    if(ipdbgJtagWrite(chain, auslesen, 1, IPDBG_LA_VALID_MASK) != JTAG_HOST_OK)
        sr_warn("Can't send K_Mauslesen");
    //g_usleep(RESPONSE_DELAY_US);




    if(ipdbgJtagRead(chain, buf, 8, IPDBG_LA_VALID_MASK) != 8)
        sr_warn("getAddrAndDataWidth failed");

    //sr_warn("getAddrAndDataWidth 0x%x:0x%x:0x%x:0x%x 0x%x:0x%x:0x%x:0x%x", buf[0],buf[1],buf[2],buf[3],buf[4],buf[5],buf[6],buf[7]);

    devc->DATA_WIDTH  =  buf[0]        & 0x000000FF;
    devc->DATA_WIDTH |= (buf[1] <<  8) & 0x0000FF00;
    devc->DATA_WIDTH |= (buf[2] << 16) & 0x00FF0000;
    devc->DATA_WIDTH |= (buf[3] << 24) & 0xFF000000;

    devc->ADDR_WIDTH  =  buf[4]        & 0x000000FF;
    devc->ADDR_WIDTH |= (buf[5] <<  8) & 0x0000FF00;
    devc->ADDR_WIDTH |= (buf[6] << 16) & 0x00FF0000;
    devc->ADDR_WIDTH |= (buf[7] << 24) & 0xFF000000;



    //sr_warn("Datawidth: %d  Addrwdth : %d", devc->DATA_WIDTH, devc->ADDR_WIDTH);

    int HOST_WORD_SIZE = 8; // bits/ word

    devc->DATA_WIDTH_BYTES = (devc->DATA_WIDTH+HOST_WORD_SIZE -1)/HOST_WORD_SIZE;
    devc->ADDR_WIDTH_BYTES = (devc->ADDR_WIDTH+HOST_WORD_SIZE -1)/HOST_WORD_SIZE;
    devc->limit_samples = (0x01 << devc->ADDR_WIDTH);
    //sr_warn("DATA_WIDTH_BYTES: %d  ADDR_WIDTH_BYTES : %d", devc->DATA_WIDTH_BYTES, devc->ADDR_WIDTH_BYTES);



    devc->trigger_mask       = g_malloc0(devc->DATA_WIDTH_BYTES);
    devc->trigger_value      = g_malloc0(devc->DATA_WIDTH_BYTES);
    devc->trigger_mask_last  = g_malloc0(devc->DATA_WIDTH_BYTES);
    devc->trigger_value_last = g_malloc0(devc->DATA_WIDTH_BYTES);


}
SR_PRIV struct ipdbgla_dev_context *ipdbgla_dev_new(void)
{
    struct ipdbgla_dev_context *devc;

    devc = g_malloc0(sizeof(struct ipdbgla_dev_context));



    devc->capture_ratio = 50;
    ///devc->num_bytes = 0;

    return devc;
}
SR_PRIV int setReset(urj_chain_t *chain)
{
    uint8_t buf[1];
    buf[0]= reset;
    if(ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK) != JTAG_HOST_OK)
        sr_warn("Reset can't send");
    return JTAG_HOST_OK;
}
SR_PRIV int requestID(urj_chain_t *chain)
{
    uint8_t buf[1];
    buf[0]= IDBG;
    if(ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK) != JTAG_HOST_OK)
        sr_warn("IDBG can't send");

    char ID[4];
    if(ipdbgJtagRead(chain, (uint8_t*)ID, 4, IPDBG_LA_VALID_MASK) != 4)
        sr_warn("IDBG can't red");


    if (strncmp(ID, "IDBG", 4)) {
        sr_err("Invalid reply (expected 'IDBG' '%c%c%c%c').", ID[0], ID[1], ID[2], ID[3]);
        return SR_ERR;
    }


    return JTAG_HOST_OK;
}

SR_PRIV void ipdbg_abort_acquisition(const struct sr_dev_inst *sdi)
{
    struct sr_datafeed_packet packet;
    //urj_chain_t *chain;

    //chain = sdi->conn;
    //serial_source_remove(sdi->session, serial);

	sr_session_source_remove(sdi->session, -1);

    /* Terminate session */
    packet.type = SR_DF_END;
    sr_session_send(sdi, &packet);
}

SR_PRIV int setStart(urj_chain_t *chain)
{
    uint8_t buf[1];
    buf[0] = Start;

   if(ipdbgJtagWrite(chain, buf, 1, IPDBG_LA_VALID_MASK) != JTAG_HOST_OK)
        sr_warn("Reset can't send");
    return JTAG_HOST_OK;
}



