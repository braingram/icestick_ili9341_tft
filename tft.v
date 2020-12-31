module tft #(
) (
	input CLK,
	output RD,
	output WR,
	output RST,
	output CD,
	output CS,
	output D0,
	output D1,
	output D2,
	output D3,
	output D4,
	output D5,
	output D6,
	output D7,
	output LED1,
	output LED2,
	output LED3,
	output LED4,
	output LED5
);
	wire [7:0] data;
	assign data = {D7, D6, D5, D4, D3, D2, D1, D0};

	wire [4:0] debug;
	assign {LED5, LED4, LED3, LED2, LED1} = debug;

	localparam integer N_COLORS = 3;
	reg [16:0] colors [0:N_COLORS-1];
	reg [$clog2(N_COLORS)-1:0] color_index = 0;

	initial begin
		colors[0] = 16'hf800;
		colors[1] = 16'h03e0;
		colors[2] = 16'h000f;
	end

	reg [16:0] fill_color = 0;

	localparam integer cdiv_bits = 24;
	reg [cdiv_bits-1:0] cdiv = 0;

	always @(posedge CLK) begin
		cdiv <= cdiv + 1;
		if (cdiv == 0) begin
			if (color_index == 0) begin
				color_index <= N_COLORS - 1;
			end else begin
				color_index <= color_index - 1;
			end
			fill_color <= colors[color_index];
		end
	end

	ili9341 #(
		.CLOCK_FREQ_HZ(12000000)
	) tft_1 (
		.fill_color(fill_color),
		.in_clk(CLK),
		.in_rst(1'b0),
		.out_rd(RD),
		.out_wr(WR),
		.out_rst(RST),
		.out_cd(CD),
		.out_cs(CS),
		.out_data(data),
		.debug(debug));
endmodule
