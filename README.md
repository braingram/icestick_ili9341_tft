ILI9341

Init commands from Adafruit library
soft reset[0x01] 0
wait 50 ms
displayoff[0x28] 0
powercontrol1[0xc0] 0x23 [4.6 volts]
powercontrol2[0xc1] 0x10 [?]
vcomcontrol1[0xc5] 0x2B2B [3.775, -1.425]
vcomcontrol2[0xc7] 0xc0 [VCOMH=VMH, VCOML=VML]
memcontrol[0x36] (byte) (madctl_MY | madctl_bgr) [0x88]
pixelformat/colmod[0x3a] 0x55 [16 bits per pixel]
framecontrol[0xb1] 0x001b h=0x00 l=0x1b [fosc/1, 70 hz]
entrymode[0xb7] 0x07 [low voltage detection on, normal display]
sleepout[0x11] 0
wait 150 ms (only needs to wait 5 ms per datasheet)
displayon[0x29] 0
delay 500 ms (datasheet doesn't spec wait time)
//setaddrwindow (0, 0, width-1, height-1) which becomes...
coladdrset[0x2a] (32 bit) (0 << 16) | (screen width-1)
pageaddrset[0x2b] (32 bit) (0 << 16) | (screen height-1)

Data is transmitted using a sequence like this:
- CS active
- set CD to command (high/low?)
- write register address (byte)
- set CD to data (high/low?)
- write values starting with MSB
- inactivate CS

To fill screen,
setAddrWindow to whole screen
CS active, CD command, send memorywrite[0x2c]
CD data, 
Transmit color for each pixel as high then low byte


Maybe use color set (0x2d) to make pallete lookups

from verilog code: https://github.com/Poofjunior/HardwareModules/blob/master/ILI9341_MCU_Parallel_Ctrl/ILI9341_MCU_Parallel_Ctrl.sv

init: bring reset line low, wait 200 ms
hold_reset: bring reset line high, wait 120 ms
transfer_sync: send 3 NOPS (all 0)
transfer_sync_delay: wait 5 ms
send_init_params: send each init param (no delay)
wait_to_send: wait 120 ms
enable_display: send 0x29
enable_display_wait: wait 120 ms
send_pixel_loc: 0x2a etc 0x2b etc 0x2c
send_pixel_data: pixels, if new frame goto send_pixel_loc)
done: (go to send_pixel_loc)


tft pin information (signals are active low, commands active on rising edge)
rst: can also be reset by software
rd: 
wr:
cd: low = command
cs:

tie some pins: cs low, rst high, rd high
just leaves wr and cd
0x000 ; 3 NOPs (cd low) to sync
0x000 ; NOP
0x000 ; NOP
0x001 ; software reset
-- TODO then wait 5 ms --
0x028 ; display off
0x0c0 0x123 ; powercontrol1 to 4.6 volts
0x0c1 0x110 ; powercontrol2 to ?
0x0c5 0x12b 0x12b ; vcomcontrol1 to 3.775, -1.425
0x0c7 0x1c0 ; vcomcontrol2 to VCOMH=VMH, VCOML=VML
0x036 0x188 ; memcontrol to MY, BGR
0x03a 0x155 ; colmod to 16 bits per pixel
0x0b1 0x100 0x11b ; framecontrol to fosc/1, 70 hz
0x0b7 0x107 ; entrymode to low v detect, normal display
0x029 ; display on
0x011 ; sleep out
-- TODO then wait 120 ms (is this needed?) --

States:
RESET (do nothing)
CLEAR (3 nops, reset, wait 5ms)
CONFIGURE (send config [above], wait 120 ms)
SETLOC (send location)
RENDER (write pixels, goto setloc)


Prior to simplification
Info: Device utilisation:
Info: 	         ICESTORM_LC:   247/ 1280    19%
Info: 	        ICESTORM_RAM:     0/   16     0%
Info: 	               SB_IO:    19/  112    16%
Info: 	               SB_GB:     4/    8    50%
Info: 	        ICESTORM_PLL:     0/    1     0%
Info: 	         SB_WARMBOOT:     0/    1     0%

After simplification
Info: Device utilisation:
Info: 	         ICESTORM_LC:   153/ 1280    11%
Info: 	        ICESTORM_RAM:     1/   16     6%
Info: 	               SB_IO:    19/  112    16%
Info: 	               SB_GB:     5/    8    62%
Info: 	        ICESTORM_PLL:     0/    1     0%
Info: 	         SB_WARMBOOT:     0/    1     0%
