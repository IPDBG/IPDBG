#include <vpi_user.h>
#include <thread>

#include "JtagHostLoop.h"

extern "C"
{
//procedure set_data_to_jtag_host(data : integer);
static int set_data_to_jtag_host_vpi(char *userdata)
{
    vpiHandle systfref, args_iter, argh;
    struct t_vpi_value argval;
    int32_t value;

    // Obtain a handle to the argument list
    systfref = vpi_handle(vpiSysTfCall, NULL);
    args_iter = vpi_iterate(vpiArgument, systfref);

    // Grab the value of the first argument
    argh = vpi_scan(args_iter);
    argval.format = vpiIntVal;
    vpi_get_value(argh, &argval);
    value = argval.value.integer;

    set_data_to_jtag_host(static_cast<uint32_t>(value & 0x7fffffffl));
    //vpi_printf("VPI routine received %d\n", value);

    // Cleanup and return
    vpi_free_object(args_iter);
    return 0;
}

void register_set_data_to_jtag_host()
{
    s_vpi_systf_data tf_data;

    tf_data.type        = vpiSysTask;
    tf_data.sysfunctype = 0;
    tf_data.tfname      = "$set_data_to_jtag_host";
    tf_data.calltf      = set_data_to_jtag_host_vpi;
    tf_data.compiletf   = 0;
    tf_data.sizetf      = 0;
    tf_data.user_data   = 0;
    vpi_register_systf(&tf_data);
}

//function get_data_from_jtag_host(unused : integer) return integer;
static int get_data_from_jtag_host_vpi(char *userdata)
{
    vpiHandle systfref, args_iter, argh;
    struct t_vpi_value argval;

    // Obtain a handle to the argument list
    systfref = vpi_handle(vpiSysTfCall, NULL);
    args_iter = vpi_iterate(vpiArgument, systfref);

    // Grab the value of the first argument
    argh = vpi_scan(args_iter);
    argval.format = vpiIntVal;
    vpi_get_value(argh, &argval);

    // Increment the value and put it back as first argument
    argval.value.integer = static_cast<int32_t>(get_data_from_jtag_host(0) & 0x7fffffff);
    vpi_put_value(argh, &argval, NULL, vpiNoDelay);

    // Cleanup and return
    vpi_free_object(args_iter);
    return 0;
}
void register_get_data_from_jtag_host()
{
    s_vpi_systf_data tf_data;

    tf_data.type        = vpiSysTask;
    tf_data.sysfunctype = 0;
    tf_data.tfname      = "$get_data_from_jtag_host";
    tf_data.calltf      = get_data_from_jtag_host_vpi;
    tf_data.compiletf   = 0;
    tf_data.sizetf      = 0;
    tf_data.user_data   = 0;
    vpi_register_systf(&tf_data);
}

int jtagHostLoop();

static int JtagHostLoop_vpi(char *user_data)
{
    //std::thread *thread =
    new std::thread(jtagHostLoop);
    return 0;
}

void register_JtagHostLoop()
{
    s_vpi_systf_data tf_data;

    tf_data.type        = vpiSysTask;
    tf_data.sysfunctype = 0;
    tf_data.tfname      = "$jtaghostloop";
    tf_data.calltf      = JtagHostLoop_vpi;
    tf_data.compiletf   = 0;
    tf_data.sizetf      = 0;
    tf_data.user_data   = 0;
    vpi_register_systf(&tf_data);
}

void (*vlog_startup_routines[])() = {
    register_JtagHostLoop,
    register_set_data_to_jtag_host,
    register_get_data_from_jtag_host,
    0
};

}
