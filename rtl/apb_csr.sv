// This will be a set of APB Control/Status Registers
// This will be the Completerfw f	

import axi4_apb_bridge_pkg::*;

module apb_csr (
	input logic 					pclk,	// apb clock
	input logic 					prst_n,	// active LOW reset

	// APB Bus Signals
	input logic [PADDR_WIDTH-1:0]	paddr;
	input logic 					pready,
	input logic 					penable,
	input logic 					pwrite,
	input logic [PSTRB_WIDTH-1:0] 	pstrb,
	input logic [PSTRB_WIDTH-1:0] 	pwdata,
	//input logic 					 pselx,	//In case of more completer peripherals/modules

	// APB Outputs
	output logic [PSTRB_WIDTH-1:0] 	prdata,
	output logic 				   	pslverr				
);

	logic [PDATA_WIDTH-1:0] csr [31:0];

endmodule: apb_csr