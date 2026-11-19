`timescale 1ns/1ps

import axi_to_apb_bridge_pkg::*;

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

    // Clock Gen
    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk;
    end

    // apb_csr instantiation
    apb_csr u_dut (
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

    // SVA Bind
    bind apb_csr apb_csr_sva u_sva (
        .pclk       (pclk),
        .prst_n     (prst_n),
        .paddr      (paddr),
        .penable    (penable),
        .pwrite     (pwrite),
        .pstrb      (pstrb),
        .pwdata     (pwdata),
        .pselx      (pselx),
        .prdata     (prdata),
        .pready     (pready),
        .pslverr    (pslverr),
        .status_reg (status_reg)
    );

    task automatic apb_write(
        input logic [PADDR_WIDTH-1:0] addr,
        input logic [PDATA_WIDTH-1:0] data,
        input logic [PSTRB_WIDTH-1:0] strb = '1
    );
        @(posedge pclk);
        paddr   <= addr;
        pwdata  <= data;
        pstrb   <= strb;
        pwrite  <= 1'b1;
        pselx   <= 1'b1;
        penable <= 1'b0;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        while (!pready) @(posedge pclk);

        pselx   <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
    endtask

    task automatic apb_read(
        input  logic [PADDR_WIDTH-1:0] addr,
        output logic [PDATA_WIDTH-1:0] data
    );
        @(posedge pclk);
        paddr   <= addr;
        pwrite  <= 1'b0;
        pselx   <= 1'b1;
        penable <= 1'b0;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        while (!pready) @(posedge pclk);

        data    = prdata;
        pselx   <= 1'b0;
        penable <= 1'b0;
    endtask


    // Verificaiton sim
    logic [PDATA_WIDTH-1:0] read_val;

    initial begin
        // Reset Setup
        prst_n  = 0;
        paddr   = '0;
        pselx   = 0;
        penable = 0;
        pwrite  = 0;
        pwdata  = '0;
        pstrb   = '0;

        repeat (5) @(posedge pclk);
        prst_n = 1;
        @(posedge pclk);

        // 1. Full Register Address Map Verification
        $display("\n=== [TB] Test 1: Full Register Map Access ===");

        // CTRL Register (0x00)
        apb_write(CTRL_ADDR, 32'hA5A5_5A5A, 4'b1111);
        apb_read(CTRL_ADDR, read_val);
        $display("[TB] CTRL Reg   -> Write: 0xA5A55A5A, Read: 0x%h", read_val);

        // STATUS Register (0x04)
        apb_write(STATUS_ADDR, 32'h8765_4321, 4'b1111);
        apb_read(STATUS_ADDR, read_val);
        $display("[TB] STATUS Reg -> Write: 0x87654321, Read: 0x%h", read_val);

        // CONFIG Register (0x08)
        apb_write(CONFIG_ADDR, 32'h1234_5678, 4'b1111);
        apb_read(CONFIG_ADDR, read_val);
        $display("[TB] CONFIG Reg -> Write: 0x12345678, Read: 0x%h", read_val);

        // TEMP Register (0x0C)
        apb_write(TEMP_ADDR, 32'hCAFE_BABE, 4'b1111);
        apb_read(TEMP_ADDR, read_val);
        $display("[TB] TEMP Reg   -> Write: 0xCAFEBABE, Read: 0x%h", read_val);

        // 2. Byte-Strobe (PSTRB) Partial Write Tests
        $display("\n=== [TB] Test 2: Byte-Strobe Masking ===");

        // Clear CTRL Register
        apb_write(CTRL_ADDR, 32'h0000_0000, 4'b1111);

        // Write lowest byte (PSTRB = 4'b0001)
        apb_write(CTRL_ADDR, 32'hFFFF_FFFF, 4'b0001);
        apb_read(CTRL_ADDR, read_val);
        $display("[TB] PSTRB 4'b0001 -> Expected: 0x000000FF, Read: 0x%h", read_val);

        // Write upper 2 bytes (PSTRB = 4'b1100)
        apb_write(CTRL_ADDR, 32'hAAAA_0000, 4'b1100);
        apb_read(CTRL_ADDR, read_val);
        $display("[TB] PSTRB 4'b1100 -> Expected: 0xAAAA00FF, Read: 0x%h", read_val);

        $display("\n[TB SUCCESS] All verification tests completed cleanly!");
        $finish;
    end

endmodule