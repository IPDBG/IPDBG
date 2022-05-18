#include <cstdint>

class SwIoViewObserver
{
public:
    virtual void writeData(uint8_t *data, size_t length) = 0;
    virtual void readData(uint8_t **data, size_t length) = 0;
};

template <size_t OUTPUT_WIDTH, size_t INPUT_WIDTH>
class SwIoView
{
public:
    SwIoView(SwIoViewObserver *obs);
    virtual ~SwIoView();

    void ctrlWrite(uint8_t d);
    bool ctrlRead(uint8_t &d);

private:
    SwIoViewObserver *obs_;
private:
    static constexpr size_t HOST_WORD_WIDTH    = 8;
    static constexpr uint8_t read_widths_cmd  = 0xAB;
    static constexpr uint8_t write_output_cmd = 0xBB;
    static constexpr uint8_t read_input_cmd   = 0xAA;

    static constexpr size_t output_size = (OUTPUT_WIDTH + HOST_WORD_WIDTH - 1) / HOST_WORD_WIDTH;
    static constexpr size_t input_size = (INPUT_WIDTH + HOST_WORD_WIDTH - 1) / HOST_WORD_WIDTH;

    static constexpr uint8_t widths[8] = {
        (OUTPUT_WIDTH)            % 0xff,
        (OUTPUT_WIDTH / 256)      % 0xff,
        (OUTPUT_WIDTH / 65536)    % 0xff,
        (OUTPUT_WIDTH / 16777216) % 0xff,
        (INPUT_WIDTH)             % 0xff,
        (INPUT_WIDTH / 256)       % 0xff,
        (INPUT_WIDTH / 65536)     % 0xff,
        (INPUT_WIDTH / 16777216)  % 0xff
    };

    enum class states
    {
        init,
        read_width,
        set_output,
        read_input
    };

    states state_;

    uint8_t *readData_;
    uint8_t *writeData_;
    size_t readDataLength_;
    size_t writeDataLength_;
    size_t bytesReceived_;
    size_t bytesTransmitted_;

//    uint8_t outputData_;
//    bool outputDataValid_;

    void processDataStateInit(uint8_t d);
    void processSetOutputState(uint8_t d);
    bool processReadWidthState(uint8_t &d);
    bool processReadDataState(uint8_t &d);

    void reset()
    {
        state_ = states::init;
        escaping_ = false;
    }

    bool escaping_;
};

template <size_t OUTPUT_WIDTH, size_t INPUT_WIDTH>
SwIoView<OUTPUT_WIDTH, INPUT_WIDTH>::SwIoView(SwIoViewObserver *obs):
    obs_(obs),
    state_(states::init),
    readData_(nullptr),
    writeData_(nullptr),
    bytesReceived_(0),
    bytesTransmitted_(0),
    escaping_(false)
{
}

template <size_t OUTPUT_WIDTH, size_t INPUT_WIDTH>
SwIoView<OUTPUT_WIDTH, INPUT_WIDTH>::~SwIoView()
{
    if (readData_)
        delete[] readData_;
    if (writeData_)
        delete[] writeData_;
}

template <size_t OUTPUT_WIDTH, size_t INPUT_WIDTH>
void SwIoView<OUTPUT_WIDTH, INPUT_WIDTH>::ctrlWrite(uint8_t d)
{
    constexpr uint8_t escape_symbol = 0x55;
    constexpr uint8_t reset_symbol = 0xEE;

    if (!escaping_)
    {
        if (d == escape_symbol)
        {
            escaping_ = true;
            return;
        }
        if (d == reset_symbol)
        {
            reset();
            return;
        }
    }
    escaping_ = false;

    switch (state_)
    {
        case states::init: processDataStateInit(d);
            break;
        case states::read_width:
            break;
        case states::set_output: processSetOutputState(d);
            break;
        case states::read_input:
            break;
    }
}

template <size_t OUTPUT_WIDTH, size_t INPUT_WIDTH>
bool SwIoView<OUTPUT_WIDTH, INPUT_WIDTH>::ctrlRead(uint8_t &d)
{
    switch (state_)
    {
        case states::read_width: return processReadWidthState(d);
        case states::read_input: return processReadDataState(d);
        case states::set_output:
        case states::init:
            break;
    }
    return false;
}

template <size_t OUTPUT_WIDTH, size_t INPUT_WIDTH>
void SwIoView<OUTPUT_WIDTH, INPUT_WIDTH>::processDataStateInit(uint8_t d)
{
    bytesReceived_ = 0;
    bytesTransmitted_ = 0;
    switch(d){
    case read_widths_cmd: state_ = states::read_width;
        break;
    case write_output_cmd: state_ = states::set_output;
        if (!writeData_)
            writeData_ = new uint8_t[output_size];
        break;
    case read_input_cmd: state_ = states::read_input;
        if (!readData_)
            readData_ = new uint8_t[input_size];
        uint8_t *newData = nullptr;
        if (obs_)
            obs_->readData(&newData, input_size);
        if (newData)
        {
            for (size_t i = 0; i < input_size ; ++i)
                readData_[i] = newData[i];
        }
    }
}

template <size_t OUTPUT_WIDTH, size_t INPUT_WIDTH>
void SwIoView<OUTPUT_WIDTH, INPUT_WIDTH>::processSetOutputState(uint8_t d)
{
    if (!writeData_)
        return;
    writeData_[bytesReceived_++] = d;

    if (bytesReceived_ == output_size)
    {
        if (obs_)
            obs_->writeData(writeData_, output_size);
        state_ = states::init;
    }
}

template <size_t OUTPUT_WIDTH, size_t INPUT_WIDTH>
bool SwIoView<OUTPUT_WIDTH, INPUT_WIDTH>::processReadWidthState(uint8_t &d)
{
    d = widths[bytesTransmitted_++];

    if (bytesTransmitted_ == 8)
        state_ = states::init;
    return true;
}

template <size_t OUTPUT_WIDTH, size_t INPUT_WIDTH>
bool SwIoView<OUTPUT_WIDTH, INPUT_WIDTH>::processReadDataState(uint8_t &d)
{
    d = readData_[bytesTransmitted_++];

    if (bytesTransmitted_ == input_size)
        state_ = states::init;
    return true;
}

