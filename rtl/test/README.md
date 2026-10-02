# GHDL checks

`run.sh` runs the checks of the HDL cores with [GHDL](https://github.com/ghdl/ghdl)
(VHDL-2008). GitHub Actions runs it on every push and pull request that
changes `rtl/`, see `.github/workflows/ghdl.yml`.

```sh
rtl/test/run.sh                      # ghdl from the PATH
GHDL=/path/to/ghdl rtl/test/run.sh
```

| Check | What it does |
|-------|--------------|
| `hub-JtagHub`, `hub-JtagHub_4ext`, `hub-JtagHub_efinix`, `hub-JtagHub_proasic3` | Elaborates each hub variant with `JtagCdc` and a TAP, so a change of `JtagCdc` cannot break a variant unnoticed. The vendor libraries are empty stubs. |
| `cores` | `elab_cores.vhd` instantiates every core, bus interface and transport once and runs it for 2 µs: catches elaboration errors and failed assertions, e.g. on unsupported widths. |
| `tb_Iurt` | [Iurt testbench](../Iurt/README.md#simulation), Wishbone and AHB-Lite |
| `IpdbgUart_tb` | [UART testbench](../Uart/README.md#simulation) |

The exit status is 0 if all checks passed. A new self-checking testbench is
one more `check` in `run.sh`.

The behaviour of the cores together with OpenOCD and the host tools is
tested by the [co-simulation](../../sw/CoSim/README.md).

## License

[CERN-OHL-W-2.0](https://ohwr.org/cern_ohl_w_v2.txt)
