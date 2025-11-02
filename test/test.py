import cocotb
from random import randint
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

async def reset(uut, reset_duration=randint(1,10)):
    # assert reset
    uut._log.info("Resetting Module")
    uut.rst_n.value = 0
    await ClockCycles(uut.clk, reset_duration)
    uut.rst_n.value = 1

@cocotb.test()
async def test_apu_sanity(uut):
    # start clock
    clock = Clock(uut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())
    await ClockCycles(uut.clk, 1)
   
    # reset the module
    await reset(uut)
    await RisingEdge(uut.clk)

    # continue test ...
    await ClockCycles(uut.clk, 100)
    uut._log.info("Test Complete!")

