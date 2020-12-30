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
	//parameter integer N_CONFIGURE_BYTES = 29;
	//parameter integer N_CONFIGURE_BYTES = 24;
	parameter integer N_CONFIGURE_BYTES = 20;
	//parameter integer N_CONFIGURE_BYTES = 19;
	parameter integer N_SETLOC_BYTES = 11;
	reg [8:0] clear_data [0:N_CLEAR_BYTES-1];
	reg [8:0] configure_data [0:N_CONFIGURE_BYTES-1];
	reg [8:0] setloc_data [0:N_SETLOC_BYTES-1];

	initial begin
		$readmemh("clear_data.mem", clear_data);
		/*
		clear_data[0] = 9'h000;
		clear_data[1] = 9'h000;
		clear_data[2] = 9'h000;
		clear_data[3] = 9'h001;
		*/

		$readmemh("configure_data.mem", configure_data);
		/*
		configure_data[0] = 9'h028;
		configure_data[1] = 9'h0c0;
		configure_data[2] = 9'h123;
		configure_data[3] = 9'h0c1;
		configure_data[4] = 9'h110;
		configure_data[5] = 9'h0c5;
		configure_data[6] = 9'h12b;
		configure_data[7] = 9'h12b;
		configure_data[8] = 9'h0c7;
		configure_data[9] = 9'h1c0;
		configure_data[10] = 9'h036;
		configure_data[11] = 9'h188;
		configure_data[12] = 9'h03a;
		configure_data[13] = 9'h155;
		configure_data[14] = 9'h0b1;
		configure_data[15] = 9'h100;
		configure_data[16] = 9'h101;
		configure_data[17] = 9'h0b7;
		configure_data[18] = 9'h107;
		configure_data[19] = 9'h029;
		configure_data[20] = 9'h011;
		*/

		$readmemh("setloc_data.mem", setloc_data);
		/*
		setloc_data[0] = 9'h02a;
		setloc_data[1] = 9'h100;
		setloc_data[2] = 9'h100;
		setloc_data[3] = 9'h101;
		setloc_data[4] = 9'h13f;
		setloc_data[5] = 9'h02b;
		setloc_data[6] = 9'h100;
		setloc_data[7] = 9'h100;
		setloc_data[8] = 9'h100;
		setloc_data[9] = 9'h1ef;
		setloc_data[10] = 9'h02c;
		*/
	end

	// compute delays based on clock frequency
	localparam integer POST_CLEAR_DELAY = CLOCK_FREQ_HZ * 120 / 1000;
	localparam integer POST_CONFIGURE_DELAY = CLOCK_FREQ_HZ * 120 / 1000;
	//localparam integer POST_CLEAR_DELAY = CLOCK_FREQ_HZ * 1000 / 1000;
	//localparam integer POST_CONFIGURE_DELAY = CLOCK_FREQ_HZ * 1000 / 1000;

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


	//assign debug[2:0] = state;
	//assign debug[4:3] = bytes_sent[1:0];
	//assign debug[4:0] = {state[2], wr_data[8], wr_data[2:0]};
	assign debug[4:0] = {out_rst, in_rst, wr_data[8], wr_data[1:0]};
	//assign debug[4:0] = {wr, wr_data[8], wr_data[2:0]};
	//assign debug[4:0] = {wr, wr_data[0], state[2:0]};
	//assign debug[4:0] = {wr, wr_data[0], in_clk, state[1:0]};
	//assign debug[4:0] = {state[0], bytes_sent[3:0]};
	//reg [7:0] frame_counter = 0;


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
							//delay_ticks <= 0;
							bytes_sent <= 0;
							wr <= 1;
						end else begin
							wr_data <= 9'b0;
						end
						//state <= in_rst ? STATE_RESET : STATE_CLEAR;
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
							//frame_counter <= 0;
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
							//delay_ticks <= POST_CONFIGURE_DELAY;
							delay_ticks <= 0;
							//frame_counter <= frame_counter + 1;
							//frame_counter <= {frame_counter[6:0], 1'b1};
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
							//delay_ticks <= POST_CONFIGURE_DELAY;
							delay_ticks <= 0;
							wr <= 1;
						end else begin
							if (wr) begin
								if (lsb_sent) begin
									wr_data <= 9'h1f8;
									//wr_data <= {1'b1, bytes_sent[5:0], 3'b000};
									wr_data <= {1'b1, fill_color[15:8]};
									//wr_data <= {1'b1, frame_counter[7:3], 3'b000};
									lsb_sent <= 0;
								end else begin
									//wr_data <= 9'h100;
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

			/*
			// state logic
			if ((state == STATE_RESET) | (!delay_done)) begin
				wr <= 1;
				wr_data <= 9'b0;
				//out_cd <= 0;
				//out_data <= 8'b0;
			end else if (
					(state == STATE_CLEAR) | (state == STATE_CONFIGURE) |
					(state == STATE_ENABLE) | (state == STATE_SETLOC)) begin
				if (wr) begin  // wr is high
					// send pre-packaged bytes
					case (state)
						STATE_CLEAR: wr_data <= clear_data[bytes_sent];
						STATE_CONFIGURE: wr_data <= configure_data[bytes_sent];
						STATE_ENABLE: wr_data <= 9'h029;
						STATE_SETLOC: wr_data <= setloc_data[bytes_sent];
					default: wr_data <= 9'b0;
					endcase
				end else begin
					bytes_sent <= bytes_sent + 1;
				end
				wr <= ~wr;
				lsb_sent <= 1;
			end else if (state == STATE_RENDER) begin
				// send pixel values
				// send msb [f8] then lsb [00]
				if (wr) begin  // wr is high
					if (lsb_sent) begin  // lsb sent
						//wr_data <= 9'h1f8;  // send msb
						wr_data <= 9'h1f8;  // send msb
						//wr_data <= {1'b1, bytes_sent[7:0]};
						//wr_data <= {1'b1, bytes_sent[15:8]};
						//wr_data <= {1'b1, frame_counter[15:8]};
						//wr_data <= {1'b1, frame_counter[7:0]};
						lsb_sent <= 0;
					end else begin
						wr_data <= 9'h100;  // send lsb
						wr_data <= {1'b1, bytes_sent[7:0]};
						//wr_data <= {1'b1, frame_counter[7:0]};
						//wr_data <= {1'b1, bytes_sent[15:8]};
						lsb_sent <= 1;
					end
				end else begin
					if (lsb_sent) bytes_sent <= bytes_sent + 1;
				end
				wr <= ~wr;
			end
			*/
		end
	end
endmodule
