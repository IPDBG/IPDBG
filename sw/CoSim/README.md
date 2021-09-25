# IPDBG - the environment to debug your IP
## CoSim - use your favorite tools within the simulation

Demo using the IPDBG tools such as LogicAnalyzer, IoView or WaveformGenerator within a VHDL simulation with GHDL.

To build the simulation:
> make

Start the simulation:
> ./CoSim

in a second terminal start OpenOCD:
> openocd -f ipdbg_JtagSim.cfg

Now you can connet to the logic analyzer:
> ... --driver=ipdbg-la:conn=tcp-raw/127.0.0.1/4242 ...



OpenOCD needs support for the remote_bitbang Jtag adapter and IPDBG server.
>./configure --enable-remote-bitbang
