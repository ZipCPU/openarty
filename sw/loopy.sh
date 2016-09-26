#!/bin/bash

WBREGS=host/wbregs

bash startupex.sh
sleep 4;
while true; do
	echo $WBREGS
  $WBREGS leds 0x0f8 ; sleep 1
  $WBREGS leds 0x0f4 ; sleep 1
  $WBREGS leds 0x0f2 ; sleep 1
  $WBREGS leds 0x0f1 ; sleep 1
done
