/*
* This is the package used for the whole project. It will contain
* all parameters, including widths for all signals needed and 
* defines needed states according to AMBA APB Specification.
* This will also include any enum based FSM states needed.
*/
`timescale 1ns/1ps

package axi_to_apb_bridge_pkg;

	// AXI4-Lite Parameters
	parameter int  AXI_DATA_WIDTH 			= 32;
	parameter int  AXI_ADDR_WIDTH 			= 32;
	parameter int  AXI_STRB_WIDTH 			= AXI_DATA_WIDTH / 8;

	// APB Parameters
	parameter int PDATA_WIDTH 				= 32;
	parameter int PADDR_WIDTH				= 32;
	parameter int PSTRB_WIDTH				= PDATA_WIDTH / 8;


	// Memory Mapping for Control/Status Registers
	parameter logic [PADDR_WIDTH-1:0]	CTRL_ADDR	= 'h0000_0000;
	parameter logic [PADDR_WIDTH-1:0]	STATUS_ADDR = 'h0000_0004;
	parameter logic [PADDR_WIDTH-1:0]	CONFIG_ADDR = 'h0000_0008;
	parameter logic [PADDR_WIDTH-1:0]	TEMP_ADDR	= 'h0000_000C;

	// APB FSM States
	typedef enum logic [1:0] {
		APB_IDLE,
		APB_SETUP,
		APB_ACCESS
	} apb_state_e;

	// RESP Labels (Will only use OKAY and SLEVERR for this design)
	typedef enum logic [1:0] {
		AXI_RESP_OKAY   = 2'b00,
		AXI_RESP_EXOKAY = 2'b01, // Will NOT be used
		AXI_RESP_SLVERR = 2'b10,
		AXI_RESP_DECERR = 2'b11  // Will NOT be used
	} axi_resp_e;


endpackage : axi_to_apb_bridge_pkg
