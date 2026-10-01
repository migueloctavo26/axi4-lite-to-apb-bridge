/* 
* This will be a set of APB Control/Status Registers and the Completer for
* the AXI4-lite-to-APB Bridge. The design will be implemented with no wait
* states.
*
*/

import axi4_apb_bridge_pkg::*;

module apb_csr (
	// APB Clock and Reset
	input logic 					pclk,	// apb clock
	input logic 					prst_n,	// active LOW reset

	// APB Bus Signals
	input logic [PADDR_WIDTH-1:0]	paddr,
	input logic 					penable,
	input logic 					pwrite,
	input logic [PSTRB_WIDTH-1:0] 	pstrb,
	input logic [PDATA_WIDTH-1:0] 	pwdata,
	input logic 					 pselx,

	// APB Outputs
	output logic [PDATA_WIDTH-1:0] 	prdata,
	output logic 					pready,
	output logic 				   	pslverr				
);

	logic [PDATA_WIDTH-1:0] ctrl_reg;
	logic [PDATA_WIDTH-1:0] status_reg;
	logic [PDATA_WIDTH-1:0] config_reg;
	logic [PDATA_WIDTH-1:0] temp_reg; // This register will be used for verification purposes

	// Assigned values due to READ/WRITE single cycle use of the CSR implementations
	assign penable = 1'b1;
	assign pslverr = 1'b0;


	// Sequential logic for the APB CSR Completer.
	// It will be handling the main FSM for the Completer.
	always_ff @(posedge pclk or negedge prst_n) begin
		if (!prst_n) begin
			ctrl_reg	<= '0;
			config_reg 	<= '0;
			temp_reg	<= '0;
		end
		else begin
			if (penable && psel && pwrite && !pslverr) begin
				case (paddr)
					// pwdata
					CTRL_ADDR: begin
						for (int i = 0; i < PSTRB_WIDTH; i++) begin

						end
					end

				endcase
			end

		end
	end

endmodule : apb_csr