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

#ifndef LIBSIGROK_HARDWARE_IPDBG_LA_PROTOCOL_H
#define LIBSIGROK_HARDWARE_IPDBG_LA_PROTOCOL_H


#include <urjtag/chain.h>

#include <stdint.h>
#include <glib.h>
#include <libsigrok/libsigrok.h>
#include "libsigrok-internal.h"

#define LOG_PREFIX "ipdbg-la"

#define JTAG_HOST_OK 0
#define JTAG_HOST_ERR -1



/** Private, per-device-instance driver context. */
struct ipdbgla_dev_context {

	int DATA_WIDTH;
    int DATA_WIDTH_BYTES;
    int ADDR_WIDTH;
    int ADDR_WIDTH_BYTES ;


    unsigned int limit_samples;
    char capture_ratio;
    char *trigger_mask;
    char *trigger_value;
    char *trigger_mask_last;
    char *trigger_value_last;
    unsigned int delay_value;
    int num_stages; //always 0
    unsigned int num_transfers;
    unsigned char *raw_sample_buf;
};


SR_PRIV struct ipdbgla_dev_context *ipdbgla_dev_new(void);
SR_PRIV void getAddrWidthAndDataWidth(urj_chain_t *chain, struct ipdbgla_dev_context *devc);
SR_PRIV int setReset(urj_chain_t *chain);
SR_PRIV int requestID(urj_chain_t *chain);
SR_PRIV int setStart(urj_chain_t *chain);
SR_PRIV int sendTrigger(struct ipdbgla_dev_context *devc, urj_chain_t *chain);
SR_PRIV int sendDelay( struct ipdbgla_dev_context *devc, urj_chain_t *chain);
SR_PRIV int ipdbg_convert_trigger(const struct sr_dev_inst *sdi);
SR_PRIV int ipdbg_receive_data(int fd, int revents, void *cb_data);
SR_PRIV void ipdbg_abort_acquisition(const struct sr_dev_inst *sdi);


#endif
