# Cλash & Vivado & FPGA

## Introduction
This repository contains steps to get a simple `Blinker` example working using Clash and Vivado.
I will just about explain everything which comes to my mind and had me scratch my head in the beginning.
Hopefully this will provide a useful starting point for others who want to explore Clash and FPGA programming.

First of, my ultimate goal is to implement a Hashalgorithm and make it run on a FPGA to mine some blocks on a local blockchain.
As soon as this is done, I will link it **HERE** for interested readers to explore.

In the following I will assume that you have some kind of FPGA which is "supported" by Digilent, more on that and why later.

## Prerequesites
What do you need to follow along:
* FPGA supported by Digilent and Vivado:
    * I use the [Arty A7-35t](https://reference.digilentinc.com/reference/programmable-logic/arty-a7/start) here.
    * Which one you use really does not matter, as long as it is compatible with Vivado and you know the PIN-mappings.
* The [Vivado](https://www.xilinx.com/products/design-tools/vivado.html) software (some notes on installation on Archlinux below).
* [Cλash](http://clash-lang.github.io/):
    * I will assume you use `stack`, but if you know `cabal` chances are you understand how to translate the commands anyway.

### Notes on Installations
I had problems to install Vivado using the AUR package, which allows to have a pacman managed installation.
I would recommend to just follow the manual instructions on the [ArchWiki](https://wiki.archlinux.org/index.php/Xilinx_Vivado).

## Getting started
We will use stack and setup a new project according to the clash instructions, given on their website:

```bash
    $ stack new helloworld clash-lang/simple
```

The created project will be contained in the `helloworld` folder and contains a `README.md` itself, which should be checked out.
But this is not necessary to follow along here.
Inspecting the folder structure will reveal a lot of scaffolding which is already done for us by the simple project leaving us with minor editing.

We will leave the `helloworld/src/Example/Project.hs` untouched for now and just create our own module to write, transpile and use.
`$EDITOR` refers to an editor of your choice. Just use whatever you are comfortable with and hack along.

```bash
    $ cd helloworld
    $ mkdir src/Blinker
    $ $EDITOR src/Blinker/Blinker.hs
```

Our goal is pretty simple: Describe hardware which continuously turns an LED `on` and `off`.
The code for this description is here and contains some comments.
The comments will elaborate a bit on the functionality of the schematic and specifics to Clash:

### src/Blinker/Blinker.hs
```haskell
module Blinker.Blinker (topEntity) where

-- The configuration of this project automatically hides the implicit prelude
-- and enables a bunch of necessary language extension for Clash to work.
-- Clash provides it's own Prelude containing a lot of useful stuff for us to
-- explore.
import Clash.Prelude

-- processLED describes a transition within a `mealy` automaton. Clash enables
-- us to divide the description of our hardware and implmentation into separate
-- steps leading to (hopefully) better understandable code.
--
-- The type-signature for processLED can be written like this:
--
--  processLED :: s -> i -> (s,o)
--      where s = State
--            i = Input
--            o = Output
--
-- Recall that we are really just describing how our mealy machine will
-- transition.
--
-- What is this `Index 100000001` you might wonder. The Arty A7-35T runs with a
-- clock of 100MHz. To let our LED turn on and off in a one second interval, we
-- can use an accumulator which overflows every 100000000 == 100*10^6 time we
-- add one to it.
-- (Note, this is not the best way of implementing it but at least very easy,
-- which is our goal right now)
--
-- Clash provides us with the ability to define arbitrary bounded unsigned
-- integers via `Index n`. Thus what we are describing here is an integer
-- which does exactly what we talked about in the paragraph above.
--
-- acc and led are our current machine state.
-- acc' and led' are our updated machine state.
-- led' is also used as the OUTPUT of our machine. What happens is, that Clash
-- will use this output as a `Signal` which turns the power of the LED ON or
-- OFF. We obviously only need one bit to represent the ON or OFF state, thus
-- we also use the Clash provided `Bit` type.
--
-- The input `a` here is polymorphic. We will just plug the `Clock` in as the
-- input and ignore the input here. This basically means each rising edge of
-- our clock will lead to a state transition, thus incrementing our
-- accumulator and possibly flipping the state of our `led`.
processLED :: (Index 100000001, Bit) -> a -> ((Index 100000001, Bit), Bit)
processLED (acc, led) _ = ((acc', led'), led')
    where
        acc' = acc + 1
        led' | acc == 0 = complement led
             | otherwise = led


-- What follows here is an `Annotation`. The annotation is not necessary for
-- this project to work BUT it will greatly ease what we have to do in the next
-- step.
-- The `topEntity` will be used as Clash's "main" entry point. This is default
-- behaviour.
--
-- t_name = "helloworld" tells Clash how to name the entity in the generated
-- VHDL/Verilog.
--
-- t_inputs = Allows us to define HOW the inputs of our generated module are
-- named. Here we say that we expect our module to have at least one input
-- named "clk". (Note that Clash will add inputs with autogenerated names, when
-- it determines that our module does use more than specified. In this case the
-- naming SEEMS to be in the order of the described list.
--
-- t_output = Allows us to define HOW the output of our generated module is
-- named. Simply "led" here.
{-# ANN topEntity
    (Synthesize
        { t_name = "helloworld"
        , t_inputs = [ PortName "clk" ]
        , t_output = PortName "led"
        }) #-}
-- Most of the stuff works in some kind of `Domain`. Since we are using Vivado,
-- which in the end is just a Xilinx system, we can use the clash defined
-- Domain = XilinxSystem.
-- The XilinxSystem defines a clock which is per default 100MHz, which is why
-- we do not have more to do. IF your FPGA has a different clock, you would
-- need to create a custom `Domain` which in turn describes a Clock with the
-- right frequency. Then you would need to use `Clock MyDomain -> Signal
-- MyDomain -- Bit` here.
--
-- The implementation of our circuit is pretty straight forward:
topEntity :: Clock XilinxSystem -> Signal XilinxSystem Bit
topEntity clk = exposeClockResetEnable (mealy processLED (0, 0) (pure clk)) clk rst en
    where
          -- `ledMachine = mealy processLED (0, 0) (pure clk)`:
          -- ledMachine uses our mealy transition function `processLED` with
          -- the initial state `(0, 0)` and the input `(pure clk)` to create a
          -- mealy machine.
          -- `clk` itself is the input to our defined hardware module. `clk` is
          -- of type `Clock XilinxSystem`, but the mealy machine requires the
          -- input to be a `Signal`, which already indicates that we are
          -- describing a sequential circuit. So to tell that we are indeed
          -- using the clock as an input, we have to "lift" `clk` to be a
          -- `Signal XilinxSystem (Clock XilinxSystem)`. This is enough for
          -- Clash to infer, that we are indeed using the given clock as an
          -- input for our defined mealy transition function.

          -- Every mealy machine is defined to accept a `Clock`, `Reset` and
          -- `Enable`. This makes sense, but it took me way to long to figure
          -- out how to tell Clash that I do not care about `Reset` and
          -- `Enable` in my described component. Clash ALWAYS implicitly routes
          -- `Clock`, `Reset` and `Enable` to your defined components and I did
          -- not want to pollute the component by extending the `topEntity` to
          -- also accept `Reset XilinxSystem` and `Enable XilinxSystem` because
          -- this would require us to EXPLICITLY define more inputs for our
          -- Bitstream generation to work, more on that later.
          rst = resetGen

          -- We also just want our component to be always active and act on the
          -- clock input signal.
          en = enableGen

          -- `exposeClockResetEnable ledMachine clk rst en`:
          -- exposeClockResetEnable allows us to expose the hidden `Clock`,
          -- `Reset` and `Enable` within `ledMachine`. Remember, this is
          -- because every mealy machine is defined to have a hidden `Clock`,
          -- `Reset` and `Enable`. We would not need this if our input to our
          -- `ledMachine` would not explicitly take in the `Clock`, but since
          -- it does, we have to do some plumbing here.
```

You can copy the above code, or just clone this repository and get the clean file.
You might also go ahead and remove the comments, because it might be the case that I hurt Haskell's feeling somewhere and the compiler will refuse to work.

What is now left to do is edit our `helloworld.cabal` to make `stack` aware about our `Blinker.Blinker` module.
Open `helloworld.cabal` in your favourite editor, which hopefully is (N)VIM, and add the `Blinker.Blinker` to the exposed-modules:

```
...

library
  import: common-options
  hs-source-dirs: src
  exposed-modules:
    Example.Project
    Blinker.Blinker
  default-language: Haskell2010
  
...
```

We will now generate the VHDL from our description by issuing following command:

```bash
    $ stack run clash -- Blinker.Blinker --vhdl
```

This will create a folder called `vhdl/Blinker.Blinker.topEntity`.
Just remember where it is located, because we will use this with Vivado in a second.

### Vivado
Hopefully, you were able to get Vivado up and running. We will now create a project:

![Project Creation](/pics/vivado_create_project.png)

When selecting the type, make sure to tick "Do not specify project sources".
![Project Type](/pics/vivado_project_type.png)

Depending on the board you use, remember I use the Arty A7-35T, you need to select the right one in the next step.
I can see the proper board part on the [A7 reference](https://reference.digilentinc.com/reference/programmable-logic/arty-a7/start) in the table under **FPGA Part #**: `XC7A35TICSG324-1L`:
![Board Part](/pics/vivado_board_part.png)

Select your board and finish.

Now add `Design Sources` to your project by clicking on the **+**:

![Sources Window](/pics/vivado_sources_window.png)

Add the `helloworld/vhdl/Blinker.Blinker.topEntity` folder as a `Design Source` and confirm:
![Add Folder](/pics/vivado_add_folder.png)

The only thing left to do, before we are able to generate the bitstream which we can use to program our FPGA with, is telling Vivado what pins to use as "clk" and "led".
The [A7 reference](https://reference.digilentinc.com/reference/programmable-logic/arty-a7/start) also has our back here:

![Master XDC](/pics/master_xdc.png)

The [Master XDC](https://github.com/Digilent/digilent-xdc/) links to a nice repository containing some supported boards where all possible pins are prepared to just be uncommented and used in Vivado.
I will use the `Arty-A7-35-Master.xdc`, you can either use the whole file and uncomment only what you need, or just copy and paste directly what is necessary.
For this we first have to create a `constraints` file in vivado.
Simply use the **+** again and this time choose "Add or create constraints" and create a file called "helloworld":

![Add Constraints](/pics/vivado_constraints.png)

Double click the file in the `Sources` pane of Vivado under `Constraints -> constrs_1 -> helloworld.xdc` and you shall be greeted by an empty editor.

Out of the `Master XDC` I will take the `Clock` and a `LED`:

### helloworld.xdc
```
## Clock signal
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }]; #IO_L12P_T1_MRCC_35 Sch=gclk[100]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { CLK100MHZ }];

## LEDs
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; #IO_L24N_T3_35 Sch=led[4]
```

Note that the `CLK100MHZ` and `led[0]` define the variable names which Vivado will use to interpret our circuit.
Remember that we defined our component to use `clk` as input and `led` as output, thus I will change the naming here to reflect that.
I also left a comment on how we told Clash to ignore the `Reset XilinxSytem` and `Enable XilinxSytem`.
If we would not have done that, we would be required to specify more clocks in this `helloworld.xdc` file, which we would need to map to some inputs of our component.
Since we ignored `Reset` and `Enable`, the only things to map are `led` and `clk`.

### helloworld.xdc
```
## Clock signal
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L12P_T1_MRCC_35 Sch=gclk[100]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## LEDs
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { led }]; #IO_L24N_T3_35 Sch=led[4]
```

Save the file.
Right click `helloworld.xdc` in the `Sources` pane and click on `Set as target constraint file`.
This tells Vivado to really use this constraint file for the synthesis and co.

## Wrapping up and getting our design on the board
Nice, we are almost done.
If everything went well up to this point, and Vivado does not complain about syntax errors in our `helloworld.vhdl` we can click on `Generate Bitstream`.
This will create a popup informing us that more steps are required, just accept this, then press `OK` and wait for vivado to get the job done.

![Confirm Result](/pics/vivado_confirm_result.png)

![Vivado Working](/pics/vivado_synth.png)

As soon as vivado is done you should be greeted with a popup, select `Open Hardware Manager` and continue.

![Hardware Manager](/pics/vivado_open_hwm.png)

If not done yet, connect your FPGA with your PC.
Since the A7-35t is programmable over JTAG I just have to connect the Micro-USB cable and select `Open target -> Auto Connect`.

![Open Target](/pics/vivado_open_target.png)
![Connected Target](/pics/vivado_hw_connected.png)

With the A7 recognized and connected, simply right-click `xc7a35t_0` in the `Hardware` pane and select `Program device`.
The bitstream file is located in:
```$PATHTOVIVADOPROJECT/fpgablinker/fpgablinker.runs/impl_1/helloworld.bit```
Select it and press on `Program`.

## Final words
With this done, you should hopefully see some LED blinking on your board.
If you had any problems along the way open a PR and tell me about it, I will try to update this since the more tutorials we have the better.
I created this write-up because I felt a little bit lost even though all the steps here are very basic and simple.
Having already forgotten most of the Verilog I was taught in University and just jumping right into Clash and learning about Vivado, VHDL, Clash and all the nitbits was rather painful.
Maybe I was able to alleviate some of the pains when starting out, especially in regards to Clash and FPGA programming.
