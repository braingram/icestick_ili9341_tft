module config_ram (
	input in_clk,
	input [5:0] in_addr,
	output [9:0] out_data
);

	reg [9:0] data [0:35];

	initial begin
		$readmemh("init_data.mem", data);
	end

	always @(negedge in_clk) begin
		out_data <= data[in_addr];
	end
endmodule
