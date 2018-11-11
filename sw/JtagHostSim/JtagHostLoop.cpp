#include <queue>
#include <boost/thread/mutex.hpp>

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


extern "C" uint32_t get_data_from_jtag_host(uint32_t unused)// called by JtagHub_sim
{
    uint32_t retVal = 0;
    // by design the JtagHost has to poll for new data JtagHost is master on The JTAG interface, so here it puts a lot of zeros which we remove here to speed up the simulation
    while(!dwn_queue.empty())
    {
        retVal = static_cast<uint32_t>(dwn_queue.front());
        dwn_queue.pop();
        if (retVal != 0)
            return retVal;
    }
    return 0;
}

extern "C" void set_data_to_jtag_host(uint32_t data) // called by JtagHub_sim
{
    up_queue.push(static_cast<uint16_t>(data));
}

extern "C" int16_t get_data_from_jtag_hub()
{
    uint16_t retVal = 0;
    if(!up_queue.empty())
    {
        retVal = up_queue.front();
        up_queue.pop();
    }

    return retVal;
}

extern "C" void set_data_to_jtag_hub(uint16_t dat)
{
    dwn_queue.push(dat);
}
