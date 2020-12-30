PROJ = tft

PIN_DEF = icestick.pcf
DEVICE = hx1k

FILES = $(PROJ).v
FILES += ili9341_tft.v

all: $(PROJ).rpt $(PROJ).bin

# for some reason yosys needed -retime to avoid errors:
# 5.34. Executing DFFLEGALIZE pass (convert FFs to types supported by the target).
# ERROR: FF pewpew.$auto$simplemap.cc:581:simplemap_dlatch$1353 (type $_DLATCH_N_) cannot be legalized: initialized dlatch are not supported
# make: *** [Makefile:16: pewpew.json] Error 1
#
# I think this is a problem with matching the cmd_enable/disable_match to reset logic
# which yosys wants to make into a dlatch but the yosys abc command fails to match
# to the ice40 hardware

%.json: %.v $(FILES)
	yosys -p 'synth_ice40 -top $(PROJ) -retime -json $@' $(FILES)

%.asc: %.json
	nextpnr-ice40 --$(DEVICE) --json $^ --pcf $(PIN_DEF) --asc $@

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $@ $<

%_tb: %_tb.v %.v
	iverilog -o $@ $^

%_tb.vcd: %_tb
	vvp -N $< +vcd=$@

%_syn.v: %.blif
	yosys -p 'read_blif -wideports $^; write_verilog $@'

%_syntb: %_tb.v %_syn.v
	iverilog -o $@ $^ `yosys-config --datdir/ice40/cells_sim.v`

%_syntb.vcd: %_syntb
	vvp -N $< +vcd=$@

sim: $(PROJ)_tb.vcd
	gtkwave $^ --rcvar 'enable_vcd_autosave yes' --rcvar 'do_initial_zoom_fit yes' --rcvar 'splash_disable yes'

postsim: $(PROJ)_syntb.vcd

prog: $(PROJ).bin
	iceprog $<

screen: prog
	screen -fn /dev/ttyUSB1 9600

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo iceprog $<

clean:
	rm -f $(PROJ).json $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin $(PROJ)_tb.vcd $(PROJ)_tb vcd_autosave.sav

.SECONDARY:
.PHONY: all prog clean
