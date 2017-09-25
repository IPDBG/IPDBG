#include <iostream>
#include <thread>
#include <queue>
#include <boost/thread/mutex.hpp>

extern "C" int jtagHostLoop();

extern "C" int ghdl_main(int argc, char **argv);

void ghdl_run()
{
    std::cout << "calling the vhdl simulator!" << std::endl;
    //char *ghdl_args[] = {(char*)"uut", (char*)"--stop-time=5000ns", (char*)"--assert-level=failure", (char*)"--wave=wave.ghw"};
    char *ghdl_args[] = {(char*)"tb_top"};
    ghdl_main(1, ghdl_args);

    return;
}

template<typename Data>
class concurrent_queue
{
private:
    std::queue<Data> the_queue;
    mutable boost::mutex the_mutex;
public:
    void push(const Data& data)
    {
        boost::mutex::scoped_lock lock(the_mutex);
        the_queue.push(data);
    }

    bool empty() const
    {
        boost::mutex::scoped_lock lock(the_mutex);
        return the_queue.empty();
    }

    Data& front()
    {
        boost::mutex::scoped_lock lock(the_mutex);
        return the_queue.front();
    }

    Data const& front() const
    {
        boost::mutex::scoped_lock lock(the_mutex);
        return the_queue.front();
    }

    void pop()
    {
        boost::mutex::scoped_lock lock(the_mutex);
        the_queue.pop();
    }
};

concurrent_queue<uint16_t> dwn_queue, up_queue;


extern "C" uint32_t get_data_from_jtag_host(uint32_t unused)
{
    uint32_t retVal = 0;
    if(!dwn_queue.empty())
    {
        retVal = static_cast<uint32_t>(dwn_queue.front());
        if(retVal != 0)
        std::cout << "get_data_from_jtag_host: 0x" << std::hex << retVal << std::endl;
        dwn_queue.pop();
    }
    return retVal;
}

extern "C" void set_data_to_jtag_host(uint32_t data) // called by JtagHub_sim
{
    if(data != 0)
    std::cout << "set_data_to_jtag_host(0x" << std::hex << data << ")"  << std::endl;
    up_queue.push(static_cast<uint16_t>(data));
}

extern "C" int16_t get_data_from_jtag_hub()
{
    uint16_t retVal = 0;
    if(!up_queue.empty())
    {
        retVal = up_queue.front();
        if(retVal != 0)
            std::cout << "get_data_from_jtag_hub: 0x" << std::hex << retVal << std::endl;
        up_queue.pop();
    }

    return retVal;
}

extern "C" void set_data_to_jtag_hub(uint16_t dat)
{
    if(dat != 0)
    std::cout << "set_data_to_jtag_hub(0x" << std::hex << dat << ")" << std::endl;
    dwn_queue.push(dat);
}


int main(int argc, const char *argv[])
{
    std::thread ghdl(ghdl_run);
    std::thread jtagHost(jtagHostLoop);

    std::cout << "main, ghdl and bar now execute concurrently...\n";

    ghdl.join();
    jtagHost.join();


    return jtagHostLoop();
}
