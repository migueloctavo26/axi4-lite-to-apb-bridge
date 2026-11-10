/*
* SystemVerilog Assertions (SVA) for the CSR APB4 Completer.
* The module will be bound to the apb_csr_tb.sv file and any future tb 
* files needed for the project. This was done for cleaner code and file structure
* throughout the project. For each SVA, there is an $error() message for better
* debugging purposes.
*/
`timescale 1ns/1ps

import axi_to_apb_bridge_pkg::*;

module apb_csr_sva (
    input logic                     pclk,
    input logic                     prst_n,
    input logic [PADDR_WIDTH-1:0]   paddr,
    input logic                     penable,
    input logic                     pwrite,
    input logic [PDATA_WIDTH-1:0]   pwdata,
    input logic                     pselx,
    input logic                     pready,
    input logic [PDATA_WIDTH-1:0]   prdata,
    input logic                     pslverr,
    input logic [PSTRB_WIDTH-1:0]   pstrb,
    input logic [PDATA_WIDTH-1:0]   status_reg
);
    // Checks that penable remains LOW during the SETUP state and gets asserted to move into the ACCESS state.
    property setup_to_access_check;
        @(posedge pclk) disable iff (!prst_n)
        $rose(pselx) |-> (!penable ##1 penable);
    endproperty
    setup_to_access_check_a: assert property (setup_to_access_check)
        else $error("[SVA Fail]: penable must be 0 in SETUP state and 1 in ACCESS state.");

    // Property: PENABLE must drop low on the cycle following a completed handshake
    property enable_deassert_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && penable && pready) |=> !penable;
    endproperty
    enable_deassert_check_a: assert property(enable_deassert_check)
        else $error("[SVA Fail]: penable remained high after transfer");

    // Checks that pready is HIGH during the ACCESS state.
    property zero_wait_check;
        @(posedge pclk) disable iff (!prst_n)
        $rose(pselx && penable) |-> pready;
    endproperty
    zero_wait_check_a: assert property (zero_wait_check)
        else $error("[SVA Fail]: pready is LOW during active transaction.");

    /* 
    * The following properties check that all signals do not change during the during the transition 
    * between the SETUP and ACCESS, and between cycles in the ACCESS state.
    */

    // Checks that pselx remains stable during the transaction.
    property pselx_stable_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && (!penable || !pready)) |=> pselx;
    endproperty
    pselx_stable_check_a: assert property(pselx_stable_check)
        else $error("[SVA Fail]: pselx changed value during transaction.");

    // Checks that paddr remains stable during the transaction.
    property paddr_stable_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && (!penable || !pready)) |=> $stable(paddr);
    endproperty
    paddr_stable_check_a: assert property(paddr_stable_check)
        else $error("[SVA Fail]: paddr changed value during transaction.");

    // Checks that pwrite remains stable during the transaction.
    property pwrite_stable_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && (!penable || !pready)) |=> $stable(pwrite);
    endproperty
    pwrite_stable_check_a: assert property(pwrite_stable_check)
        else $error("[SVA Fail]: pwrite changed during the transaction.");

    // Checks that pstrb remains the same during the transaction.
    property pstrb_stable_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && (!penable || !pready)) |=> $stable(pstrb);
    endproperty
    pstrb_stable_check_a: assert property(pstrb_stable_check)
        else $error("[SVA Fail]: pstrb changed during the transaction.");

    // Checks that pwdata does not change during a write transaction.
    property pwdata_stable_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && pwrite && (!penable || !pready)) |=> $stable(pwdata);
    endproperty
    pwdata_stable_check_a: assert property(pwdata_stable_check)
        else $error("[SVA Fail]: pwdata changed during an active write transaction.");

    // If trying to access an unmapped address, the pslverr signal will be asserted and will raise flag
    property unmapped_address_flag;
        @(posedge pclk) disable iff(!prst_n)
        (pselx && penable && (paddr != CTRL_ADDR) && (paddr != STATUS_ADDR) && 
        (paddr != CONFIG_ADDR) && (paddr != TEMP_ADDR)) |-> pslverr;
    endproperty
    unmapped_address_flag_a: assert property(unmapped_address_flag)
        else $error("[SVA Fail]: Unmapped address 0x%h access failed", paddr);

    // Checks that the READ Only Status Register is not written onto
    property status_reg_immutable_check;
        @(posedge pclk) disable iff(!prst_n)
        (pselx && penable && pwrite && (paddr == STATUS_ADDR)) |=> $stable(status_reg);
    endproperty
    status_reg_immutable_check_a: assert property(status_reg_immutable_check)
        else $error("[SVA Fail]: Status Register value was Overwritten.");

endmodule : apb_csr_sva
