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

#include <config.h>
#include "protocol.h"

#include "jtaghost.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <inttypes.h>
#include <assert.h>

#include <urjtag/chain.h>
#include <urjtag/tap.h>
#include <urjtag/part.h> //urj_parts_t


#include <urjtag/data_register.h> // urj_part_data_register_define

#include <urjtag/part_instruction.h> // urj_part_instruction
#include <urjtag/tap_register.h> // urj_tap_register_set_value

//#include <urjtag/bus.h>
//#include <urjtag/cmd.h>
//#include <urjtag/parse.h>
//#include <urjtag/jtag.h>

#include <unistd.h> // sleep();


static const uint32_t ipdbgla_drvopts[] = {
    SR_CONF_LOGIC_ANALYZER,
};

static const uint32_t ipdbg_scanopts[] = {
//    SR_CONF_CONN,
//    SR_CONF_SERIALCOMM,
};

static const uint32_t ipdbgla_devopts[] = {
    //SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
    //SR_CONF_LIMIT_SAMPLES | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
    //SR_CONF_SAMPLERATE | SR_CONF_GET | SR_CONF_SET | SR_CONF_LIST,
    SR_CONF_TRIGGER_MATCH | SR_CONF_LIST,
    SR_CONF_CAPTURE_RATIO | SR_CONF_GET | SR_CONF_SET,
};

static const int32_t ipdbgla_trigger_matches[] = {
    SR_TRIGGER_ZERO,
    SR_TRIGGER_ONE,
    SR_TRIGGER_RISING,
    SR_TRIGGER_FALLING,
    SR_TRIGGER_EDGE,
};

SR_PRIV struct sr_dev_driver ipdbg_la_driver_info;

static int init(struct sr_dev_driver *di, struct sr_context *sr_ctx)
{
	return std_init(sr_ctx, di, LOG_PREFIX);
}

static GSList *scan(struct sr_dev_driver *di, GSList *options)
{
    printf("scan\n");
	struct drv_context *drvc;
	GSList *devices;

	(void)options;

	devices = NULL;
	drvc = di->context;
	drvc->instances = NULL;

	/* TODO: scan for devices, either based on a SR_CONF_CONN option
	 * or on a USB scan. */
    urj_chain_t *chain = ipdbgJtagAllocChain();
    if (!chain)
    {
        printf("Out of memory\n");
        return NULL;
    }
    printf("Init JTAG");
    ipdbgJtagInit(chain);




    printf("set Reset");
//////////////////////////////////////////////////////////////////////////////////////////
    setReset(chain);
    setReset(chain);

    requestID(chain);

	 struct sr_dev_inst *sdi = g_malloc0(sizeof(struct sr_dev_inst));
    if(!sdi){
        sr_err("no possible to allocate sr_dev_inst");
        return NULL;
    }
    sdi->status = SR_ST_INACTIVE;
    sdi->vendor = g_strdup("ipdbg.org");
    sdi->model = g_strdup("Logic Analyzer");
    sdi->version = g_strdup("v1.0");
    sdi->driver = di;
    const size_t bufSize = 16;
    char buff[bufSize];


    struct ipdbgla_dev_context *devc = ipdbgla_dev_new();
    sdi->priv = devc;

    getAddrWidthAndDataWidth(chain, devc);

    printf("addr_width = %d, data_width = %d", devc->ADDR_WIDTH, devc->DATA_WIDTH);
    printf("limit samples = %d", devc->limit_samples);
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    for (int i = 0; i < devc->DATA_WIDTH; i++)
    {
        snprintf(buff, bufSize, "ch%d", i);
        sr_channel_new(sdi, i, SR_CHANNEL_LOGIC, TRUE, buff);
    }

    sdi->inst_type = SR_INST_USER;
    //sdi->conn = chain;

    drvc->instances = g_slist_append(drvc->instances, sdi);
    devices = g_slist_append(devices, sdi);


    sr_warn("disconnect Chain");
    ipdbgJtagClose(chain);

	return devices;
}

static GSList *dev_list(const struct sr_dev_driver *di)
{
	//return ((struct drv_context *)(di->context))->instances;
	return ((struct drv_context *)(di->context))->instances;
}

static int dev_clear(const struct sr_dev_driver *di)
{
    printf("dev_clear\n");
    return std_dev_clear(di, NULL);
/*    printf("dev_clear\n");

    struct drv_context *drvc = ((struct drv_context *)(di->context));
    drvc->instances->data;

    urj_chain_t *chain = sdi->conn;
    urj_chain_t *chain = di->conn;

    if (chain)
    {
        ipdbgJtagClose(chain);
    }
    chain = NULL;
    sdi->conn = NULL;


	return std_dev_clear(di, NULL);*/
}

static int dev_open(struct sr_dev_inst *sdi)
{
    printf("dev_open\n");
	sdi->status = SR_ST_INACTIVE;

    urj_chain_t *chain = ipdbgJtagAllocChain();
    if (!chain)
    {
        printf("Out of memory\n");
        return SR_ERR;
    }
    sdi->conn = chain;
    ipdbgJtagInit(chain);


    //setReset(chain);
    //getAddrWidthAndDataWidth(chain, devc);

	sdi->status = SR_ST_ACTIVE;

	return SR_OK;
}

static int dev_close(struct sr_dev_inst *sdi)
{

    /// should be called before a new call to scan()
	urj_chain_t *chain = sdi->conn;

    printf("dev_close\n");

	if (chain)
    {
        ipdbgJtagClose(chain);
    }
    chain = NULL;
    sdi->conn = NULL;

	sdi->status = SR_ST_INACTIVE;

	return SR_OK;
}

static int cleanup(const struct sr_dev_driver *di)
{
    printf("cleanup\n");
	dev_clear(di);

	return SR_OK;
}

static int config_get(uint32_t key, GVariant **data,
	const struct sr_dev_inst *sdi, const struct sr_channel_group *cg)
{
	int ret;

    (void)data;
    (void)cg;

    struct ipdbgla_dev_context *devc = sdi->priv;
    printf("config_get\n");

    ret = SR_OK;
    switch (key){
    case SR_CONF_CAPTURE_RATIO:
        *data = g_variant_new_uint64(devc->capture_ratio);
        break;
    default:
        return SR_ERR_NA;
    }

    return ret;
}

static int config_set(uint32_t key, GVariant *data,
	const struct sr_dev_inst *sdi, const struct sr_channel_group *cg)
{
	int ret;

    (void)data;
    (void)cg;

    if (sdi->status != SR_ST_ACTIVE)
        return SR_ERR_DEV_CLOSED;

    printf("config_set\n");
    struct ipdbgla_dev_context *devc = sdi->priv;

    ret = SR_OK;
    switch (key){
    case SR_CONF_CAPTURE_RATIO:
        devc->capture_ratio = g_variant_get_uint64(data);
        if (devc->capture_ratio < 0 || devc->capture_ratio > 100)
        {
            devc->capture_ratio = 50;
            ret = SR_ERR;
        }
        else
            ret = SR_OK;
        break;
    default:
        ret = SR_ERR_NA;
    }

    return ret;
}

static int config_list(uint32_t key, GVariant **data,
	const struct sr_dev_inst *sdi, const struct sr_channel_group *cg)
{
	(void)sdi;
    (void)data;
    (void)cg;
    printf("config_list\n");

    switch (key){
    case SR_CONF_SCAN_OPTIONS:
        *data = g_variant_new_fixed_array(G_VARIANT_TYPE_UINT32, ipdbg_scanopts, ARRAY_SIZE(ipdbg_scanopts), sizeof(uint32_t));
        break;
    case SR_CONF_DEVICE_OPTIONS:
        if (!sdi)
            *data = g_variant_new_fixed_array(G_VARIANT_TYPE_UINT32, ipdbgla_drvopts, ARRAY_SIZE(ipdbgla_drvopts), sizeof(uint32_t));
        else
            *data = g_variant_new_fixed_array(G_VARIANT_TYPE_UINT32, ipdbgla_devopts, ARRAY_SIZE(ipdbgla_devopts), sizeof(uint32_t));
        break;
    case SR_CONF_TRIGGER_MATCH:
        *data = g_variant_new_fixed_array(G_VARIANT_TYPE_INT32, ipdbgla_trigger_matches, ARRAY_SIZE(ipdbgla_trigger_matches), sizeof(int32_t));
        break;
    default:
        return SR_ERR_NA;
    }

    return SR_OK;
}

static int dev_acquisition_start(const struct sr_dev_inst *sdi, void *cb_data)
{
	(void)sdi;
	(void)cb_data;

	if (sdi->status != SR_ST_ACTIVE)
		return SR_ERR_DEV_CLOSED;
    urj_chain_t *chain = sdi->conn;

    struct ipdbgla_dev_context *devc = sdi->priv;

    ipdbg_convert_trigger(sdi);
    printf("dev_acquisition_start\n");

    /* Send Triggerkonviguration */
    sendTrigger(devc, chain);

    /* Send Delay */
    sendDelay(devc, chain);

    //std_session_send_df_header(sdi, LOG_PREFIX);
    std_session_send_df_header(cb_data, LOG_PREFIX);

	/* If the device stops sending for longer than it takes to send a byte,
	 * that means it's finished. But wait at least 100 ms to be safe.
	 */
	//sr_session_source_add(sdi->session, -1, G_IO_IN, 100, ipdbg_receive_data, (struct sr_dev_inst *)sdi);
	sr_session_source_add(sdi->session, -1, G_IO_IN, 100, ipdbg_receive_data, cb_data);

	setStart(chain);
	/* TODO: configure hardware, reset acquisition state, set up
	 * callbacks and send header packet. */

	return SR_OK;
}

static int dev_acquisition_stop(struct sr_dev_inst *sdi, void *cb_data)
{
	(void)cb_data;
	printf("dev_acquisition_stop\n");

	if (sdi->status != SR_ST_ACTIVE)
		return SR_ERR_DEV_CLOSED;

	ipdbg_abort_acquisition(sdi);
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////????????????????????

	return SR_OK;
}

SR_PRIV struct sr_dev_driver ipdbg_la_driver_info = {
	.name = "ipdbgla",
	.longname = "ipdbga",
	.api_version = 1,
	.init = init,
	.cleanup = cleanup,
	.scan = scan,
	.dev_list = dev_list,
	.dev_clear = dev_clear,
	.config_get = config_get,
	.config_set = config_set,
	.config_list = config_list,
	.dev_open = dev_open,
	.dev_close = dev_close,
	.dev_acquisition_start = dev_acquisition_start,
	.dev_acquisition_stop = dev_acquisition_stop,
	.context = NULL,
};
