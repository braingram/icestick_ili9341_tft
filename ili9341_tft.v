module ili9341 #(
	parameter integer CLOCK_FREQ_HZ = 12000000
) (
	input [16:0] fill_color,
	input in_clk,
	input in_rst,
	output out_rd,
	output out_wr,
	output out_rst,
	output out_cd,
	output out_cs,
	output [7:0] out_data,
	output [4:0] debug
);
	// set some pins to fixed values
	//assign out_rst = 1'b1;  // pull output reset high to take tft out of reset
	assign out_rd = 1'b1;  // pull read high to always write
	assign out_cs = 1'b0;  // pull chip select low to keep tft active

	// count clock ticks for adding delays between init commands
	localparam integer DELAY_TICKS = CLOCK_FREQ_HZ * 120 / 1000;
	reg [$clog2(DELAY_TICKS)-1:0] delay_ticks = 0;
	wire delay_done;
	assign delay_done = &{~delay_ticks};
	
	reg [5:0] cfg_addr;
	wire [9:0] cfg_data;

	parameter integer N_CFG = 36;
	// 0-24 is init data
	// 25-35 is pre-pixel data
	parameter integer PRERENDER_ADDR = 25;

	config_ram cfg_ram (
		.in_clk(in_clk),
		.in_addr(cfg_addr),
		.out_data(cfg_data)
	);

	// define states
	localparam integer STATE_RESET = 3'h0;
	localparam integer STATE_INIT = 3'h1;
	localparam integer STATE_RENDER = 3'h2;
	reg [1:0] state = STATE_RESET;

	// 
	localparam integer N_PIXELS = 320 * 240;
	reg [$clog2(N_PIXELS)-1:0] bytes_sent = 0;
	reg lsb_sent = 0;

	reg [8:0] wr_data = 9'b0;
	assign {out_cd, out_data} = wr_data;
	reg wr = 1;
	assign out_wr = wr;

	assign debug[4:0] = {out_rst, in_rst, wr_data[8], wr_data[1:0]};

	assign cfg_addr = bytes_sent[5:0];


	always @(posedge in_clk) begin
		if (in_rst) begin
			state <= STATE_RESET;
			out_rst <= 0;
			delay_ticks <= 0;
			bytes_sent <= 0;
			wr_data <= 9'b0;
			wr <= 1;
		end else begin
			if (delay_done) begin
				case (state)
					STATE_RESET: begin
						// based on above logic in_rst is false
						out_rst <= 1'b1;
						state <= STATE_INIT;
						delay_ticks <= DELAY_TICKS;
						bytes_sent <= 0;
						wr <= 1;
					end
					STATE_INIT: begin
						if (bytes_sent == N_CFG) begin
							state <= STATE_RENDER;
							bytes_sent <= 0;
							delay_ticks <= cfg_data[9] ? DELAY_TICKS : 0;
							wr <= 1;
						end else begin
							if (wr) begin
								wr_data <= cfg_data[8:0];
								delay_ticks <= cfg_data[9] ? DELAY_TICKS : 0;
							end else begin
								bytes_sent <= bytes_sent + 1;
							end
							wr <= ~wr;
						end
					end
					STATE_RENDER: begin
						if (bytes_sent == N_PIXELS) begin
							state <= STATE_INIT;
							bytes_sent <= PRERENDER_ADDR;
							delay_ticks <= 0;
							wr <= 1;
						end else begin
							if (wr) begin
								if (lsb_sent) begin
									wr_data <= {1'b1, fill_color[15:8]};
									lsb_sent <= 0;
								end else begin
									wr_data <= {1'b1, fill_color[7:0]};
									lsb_sent <= 1;
								end
							end else begin
								if (lsb_sent) bytes_sent <= bytes_sent + 1;
							end
							wr <= ~wr;
						end
					end
				endcase
			end else begin
				// continue delay
				delay_ticks <= delay_ticks - 1;
			end
		end
	end
endmodule
