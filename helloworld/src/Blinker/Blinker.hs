module Blinker.Blinker (topEntity) where

import Clash.Prelude

processLED :: (Index 100000001, Bit) -> a -> ((Index 100000001, Bit), Bit)
processLED (acc, led) _ = ((acc', led'), led')
    where
        acc' = acc + 1
        led' | acc == 0 = complement led
             | otherwise = led


{-# ANN topEntity
    (Synthesize
        { t_name = "helloworld"
        , t_inputs = [ PortName "clk" ]
        , t_output = PortName "led"
        }) #-}
topEntity :: Clock XilinxSystem -> Signal XilinxSystem Bit
topEntity clk = exposeClockResetEnable (mealy processLED (0, 0) (pure clk)) clk rst en
    where
          rst = resetGen
          en = enableGen
