/*
* SystemVerilog Assertions (SVA) for the CSR APB4 Completer.
* The module will be bound to the apb_csr_tb.sv file and any future tb 
* files needed for the project. This was done for cleaner code and file structure
* throughout the project. For each SVA, there is an $error() message for better
* debugging purposes.
*/

import axi4_apb_bridge_pkg::*;

module apb_csr_sva (
    input logic                   pclk,
    input logic                   prst_n,
    input logic [PADDR_WIDTH-1:0] paddr,
    input logic                   penable,
    input logic                   pwrite,
    input logic                   pselx,
    input logic                   pready,
    input logic                   pslverr,
    input logic [PDATA_WIDTH-1:0] status_reg
);
    // Checks that penable remains LOW during the SETUP state and gets asserted to move into the ACCESS state.
    property setup_to_access_check;
        @(posedge pclk) disable iff (!prst_n)
        $rose(pselx) |-> (!penable ##1 penable);
    endproperty
    setup_to_access_check_a: assert property (setup_to_access_check)
        else $error("[SVA Fail]: penable must be 0 in SETUP state and 1 in ACCESS state.");

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

    // Checks that pselx remains HIGH during the transaction.
    property pselx_stable_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && !pready) |=> pselx;
    endproperty
    pselx_stable_check_a: assert property(pselx_stable_check)
        else $error("[SVA Fail]: pselx changed value during transaction.");

    // Checks that paddr remains HIGH during the transaction.
    property paddr_stable_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && !pready) |=> $stable(paddr);
    endproperty
    paddr_stable_check_a: assert property(paddr_stable_check)
        else $error("[SVA Fail]: paddr changed value during transaction.");

    // Checks that pwrite remains HIGH during the transaction.
    property pwrite_stable_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && !pready) |=> $stable(pwrite);
    endproperty
    pwrite_stable_check_a: assert property(pwrite_stable_check)
        else $error("[SVA Fail]: pwrite changed during the transaction.");

    // Checks that pstrb remains the same during the transaction.
    property pstrb_stable_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && !pready) |=> $stable(pstrb);
    endproperty
    pstrb_stable_check_a: assert property(pstrb_stable_check)
        else $error("[SVA Fail]: pstrb changed during the transaction.");

    // Checks that pwdata does not change during a write transaction.
    property pwdata_stable_check;
        @(posedge pclk) disable iff (!prst_n)
        (pselx && pwrite && !pready) |=> $stable(pwdata)
    endproperty
    pwdata_stable_check_a: assert property(pwdata_stable_check)
        else $error("[SVA Fail]: pwdata changed during an active write transaction.");

endmodule : apb_csr_sva
