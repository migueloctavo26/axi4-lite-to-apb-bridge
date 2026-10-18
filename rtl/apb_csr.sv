/* 
* This will be a set of APB Control/Status Registers and the Completer for
* the AXI4-lite-to-APB Bridge. The design will be implemented with no wait
* states.

*/
`timescale 1ns/1ps

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
	input logic 					pselx,

	// APB Outputs
	output logic [PDATA_WIDTH-1:0] 	prdata,
	output logic 					pready,
	output logic 				   	pslverr				
);

	logic [PDATA_WIDTH-1:0] ctrl_reg;
	logic [PDATA_WIDTH-1:0] status_reg;
	logic [PDATA_WIDTH-1:0] config_reg;
	logic [PDATA_WIDTH-1:0] temp_reg; // This register will be used for testing purposes

	// Assigned value due to READ/WRITE single cycle use of the CSR implementation
	assign pready = 1'b1;
	assign status_reg = 32'hDEAD_BEEF;

	// Combinational Logic for PSLVERR flag when trying to WRITE to status_reg
	always_comb begin
		pslverr = 1'b0;

		if (pselx && penable) begin
			case (paddr)
				// Flagged Error due to Illegal WRITE operation on READ ONLY Register
				STATUS_ADDR: begin
					if (pwrite) pslverr = 1'b1;
				end

				// Legal WRITE operations
				CTRL_ADDR: begin
					pslverr = 1'b0;
				end
				CONFIG_ADDR: begin
					pslverr = 1'b0;
				end
				TEMP_ADDR: begin
					pslverr = 1'b0;
				end

				// Flagged Error due to accessing unmapped addresses
				default: begin
					pslverr = 1'b1;
				end
			endcase
		end
	end

	// Sequential logic for the APB CSR Completer
	// Handles the main FSM for the Completer
	always_ff @(posedge pclk or negedge prst_n) begin
		if (!prst_n) begin
			ctrl_reg	<= '0;
			config_reg 	<= '0;
			temp_reg	<= '0;
		end
		else begin
			if (penable && pselx && pwrite && !pslverr) begin
				case (paddr)
					// pwdata
					CTRL_ADDR: begin
						for (int i = 0; i < PSTRB_WIDTH; i++) begin
							if (pstrb[i]) begin
								ctrl_reg[i*8 +: 8] <= pwdata[i*8 +: 8];
							end
						end
					end

					TEMP_ADDR: begin
						for (int i = 0; i < PSTRB_WIDTH; i++) begin
							if (pstrb[i]) begin
								temp_reg[i*8 +: 8] <= pwdata[i*8 +: 8];
							end
						end
					end

					CONFIG_ADDR: begin
						for (int i = 0; i < PSTRB_WIDTH; i++) begin
							if (pstrb[i]) begin
								config_reg[i*8 +: 8] <= pwdata[i*8 +: 8];
							end
						end
					end

					default: begin
						// Do nothing
					end
				endcase
			end
		end
	end

	// Combinational logic for the Read Operations for APB CSR Completer.
	always_comb begin
		prdata = '0;

		if (pselx && penable && !pwrite) begin
			case (paddr)
				CTRL_ADDR: 		prdata = ctrl_reg;
				STATUS_ADDR: 	prdata = status_reg;
				CONFIG_ADDR:	prdata = config_reg;
				TEMP_ADDR: 		prdata = temp_reg;
				default: 		prdata = '0;
			endcase
		end
	end

endmodule : apb_csr