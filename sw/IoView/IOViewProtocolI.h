#ifndef IOVIEWPROTOCOLI_H_INCLUDED
#define IOVIEWPROTOCOLI_H_INCLUDED

class IOViewProtocolObserver
{
public:
    virtual void visualizeInputs(uint8_t *buffer, size_t len)=0;
    virtual void setPortWidths(unsigned int inputs, unsigned int outputs)=0;

};

class IOViewProtocolI
{
public:
    virtual void open()=0;
    virtual void close()=0;
    virtual bool isOpen()=0;
    virtual void setOutput(uint8_t *buffer, size_t len)=0;
};


#endif
