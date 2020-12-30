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

	// setup clear and configure initilization data
	parameter integer N_CLEAR_BYTES = 4;
	parameter integer N_CONFIGURE_BYTES = 20;
	parameter integer N_SETLOC_BYTES = 11;
	reg [8:0] clear_data [0:N_CLEAR_BYTES-1];
	reg [8:0] configure_data [0:N_CONFIGURE_BYTES-1];
	reg [8:0] setloc_data [0:N_SETLOC_BYTES-1];

	initial begin
		$readmemh("clear_data.mem", clear_data);
		$readmemh("configure_data.mem", configure_data);
		$readmemh("setloc_data.mem", setloc_data);
	end

	// compute delays based on clock frequency
	localparam integer POST_CLEAR_DELAY = CLOCK_FREQ_HZ * 120 / 1000;
	localparam integer POST_CONFIGURE_DELAY = CLOCK_FREQ_HZ * 120 / 1000;

	// define states
	localparam integer STATE_RESET = 3'h0;
	localparam integer STATE_CLEAR = 3'h1;
	localparam integer STATE_CONFIGURE = 3'h2;
	localparam integer STATE_ENABLE = 3'h3;
	localparam integer STATE_SETLOC = 3'h4;
	localparam integer STATE_RENDER = 3'h5;
	reg [2:0] state = STATE_RESET;

	// 
	localparam integer N_PIXELS = 320 * 240;
	reg [$clog2(N_PIXELS)-1:0] bytes_sent = 0;
	reg lsb_sent = 0;

	reg [$clog2(POST_CONFIGURE_DELAY)-1:0] delay_ticks = 0;
	wire delay_done;
	assign delay_done = &{~delay_ticks};

	reg [8:0] wr_data = 9'b0;
	assign {out_cd, out_data} = wr_data;
	reg wr = 1;
	assign out_wr = wr;

	assign debug[4:0] = {out_rst, in_rst, wr_data[8], wr_data[1:0]};

	always @(posedge in_clk) begin
		// reset logic
		if (in_rst) begin
			state <= STATE_RESET;
			out_rst <= 0;
			delay_ticks <= 0;
			bytes_sent <= 0;
			wr_data <= 9'b0;
			wr <= 1;
		end else begin
			// state transition logic
			if (delay_done) begin  // allow state transitions
				case (state)
					STATE_RESET: begin
						if (!in_rst) begin
							out_rst <= 1'b1;
							state <= STATE_CLEAR;
							delay_ticks <= POST_CONFIGURE_DELAY;
							bytes_sent <= 0;
							wr <= 1;
						end else begin
							wr_data <= 9'b0;
						end
					end
					STATE_CLEAR: begin
						if (bytes_sent == N_CLEAR_BYTES) begin
							state <= STATE_CONFIGURE;
							delay_ticks <= POST_CLEAR_DELAY;
							bytes_sent <= 0;
							wr <= 1;
						end else begin
							if (wr) begin
								wr_data <= clear_data[bytes_sent];
							end else begin
								bytes_sent <= bytes_sent + 1;
							end
							wr <= ~wr;
						end
					end
					STATE_CONFIGURE: begin
						if (bytes_sent == N_CONFIGURE_BYTES) begin
							state <= STATE_ENABLE;
							delay_ticks <= POST_CONFIGURE_DELAY;
							bytes_sent <= 0;
							wr <= 1;
						end else begin
							if (wr) begin
								wr_data <= configure_data[bytes_sent];
							end else begin
								bytes_sent <= bytes_sent + 1;
							end
							wr <= ~wr;
						end
					end
					STATE_ENABLE: begin
						if (bytes_sent == 1) begin
							state <= STATE_SETLOC;
							delay_ticks <= POST_CONFIGURE_DELAY;
							bytes_sent <= 0;
							wr <= 1;
						end else begin
							if (wr) begin
								wr_data <= 9'h029;
							end else begin
								bytes_sent <= bytes_sent + 1;
							end
							wr <= ~wr;
						end
					end
					STATE_SETLOC: begin
						if (bytes_sent == N_SETLOC_BYTES) begin
							state <= STATE_RENDER;
							bytes_sent <= 0;
							delay_ticks <= 0;
							lsb_sent <= 0;
							wr <= 1;
						end else begin
							if (wr) begin
								wr_data <= setloc_data[bytes_sent];
							end else begin
								bytes_sent <= bytes_sent + 1;
							end
							wr <= ~wr;
						end
					end
					STATE_RENDER: begin
						if (bytes_sent == N_PIXELS) begin
							state <= STATE_SETLOC;
							bytes_sent <= 0;
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
