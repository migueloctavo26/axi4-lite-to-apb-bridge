/*
* axi4_apb_bridge_pkg.sv
*
* This is the package used for the whole project. It will contain
* all parameters, including widths for all signals needed and 
* defines needed states according to AMBA APB Specification.
* This will also include any enum based FSM states needed.
*/

package axi4_apb_bridge_pkg;

	// APB Parameters
	parameter int PDATA_WIDTH = 32;
	parameter int PADDR_WIDTH = 32;
	parameter int PSTRB_WIDTH = PDATA_WIDTH / 8;

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

	// Transfer Size for PSTRB implementation
	typedef enum logic [1:0] {
		BYTE,
		HALFWORD,
		WORD
	} transfer_size_e ;

endpackage : axi4_apb_bridge_pkg
