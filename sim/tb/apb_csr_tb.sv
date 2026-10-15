`timescale 1ns/

import axi4_apb_bridge_pkg::*;

module apb_csr_tb;
    logic                    pclk;
    logic                    prst_n;
    logic [PADDR_WIDTH-1:0]  paddr;
    logic                    penable;
    logic                    pwrite;
    logic [PSTRB_WIDTH-1:0]  pstrb;
    logic [PDATA_WIDTH-1:0]  pwdata;
    logic                    pselx;

    logic [PDATA_WIDTH-1:0]  prdata;
    logic                    pready;
    logic                    pslverr;

    // Clock Gen (100 MHz)
    always #5 pclk = ~pclk;

    // DUT Instantiation
    apb_csr dut (
        .pclk    (pclk),
        .prst_n  (prst_n),
        .paddr   (paddr),
        .penable (penable),
        .pwrite  (pwrite),
        .pstrb   (pstrb),
        .pwdata  (pwdata),
        .pselx   (pselx),
        .prdata  (prdata),
        .pready  (pready),
        .pslverr (pslverr)
    );

    
endmodule : apb_csr_tb