/*
* The testbenmch used for the verification of the bridge is created to simulate
* AXI transactions in which prove that all types of transactions are wokring and being
* translated and executed as expected. This is done by creating two tasks (READ/WRITE)
* which take a specific delay input to simulate the different VALID/READY handshake signals
* for each AXI channel. As well as noral READ/WRITE transactinos to test our bridge functionality.
*
* Gemini was used to generate the test cases using the initial code that was provided by me.
* The inital block created by Gemini was revised by me to verify that it covers all desired test cases.
*/


`timescale 1ns/1ps

import axi_to_apb_bridge_pkg::*;

module bridge_tb;
    logic aclk;
    logic arst_n;

    // AXI Write Address Channel (AW)
    logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    logic                      s_axi_awvalid;
    logic                      s_axi_awready;

    // AXI Write Data Channel (W)
    logic [AXI_DATA_WIDTH-1:0] s_axi_wdata;
    logic [AXI_STRB_WIDTH-1:0] s_axi_wstrb;
    logic                      s_axi_wvalid;
    logic                      s_axi_wready;

    // AXI Write Response Channel (B)
    logic                      s_axi_bready;
    axi_resp_e                 s_axi_bresp;
    logic                      s_axi_bvalid;

    // AXI Read Address Channel (AR)
    logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    logic                      s_axi_arvalid;
    logic                      s_axi_arready;

    // AXI Read Data Channel (R)
    logic                      s_axi_rready;
    logic [AXI_DATA_WIDTH-1:0] s_axi_rdata;
    axi_resp_e                 s_axi_rresp;
    logic                      s_axi_rvalid;

    // Testbench readback variables
    logic [AXI_DATA_WIDTH-1:0] readback_data;
    axi_resp_e                 readback_status;

    bridge_top u_top (
        .aclk           (aclk),
        .arst_n         (arst_n),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rready   (s_axi_rready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bready   (s_axi_bready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid)
    );

    // Bind AXI Bridge SVA
    bind u_top.u_bridge axi_to_apb_bridge_sva bind_axi_sva (
        .aclk(aclk), .arst_n(arst_n),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rready(s_axi_rready), .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bready(s_axi_bready), .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid),
        .m_apb_paddr(u_top.apb_paddr), .m_apb_penable(u_top.apb_penable), .m_apb_pwrite(u_top.apb_pwrite),
        .m_apb_pstrb(u_top.apb_pstrb), .m_apb_pwdata(u_top.apb_pwdata), .m_apb_pselx(u_top.apb_pselx),
        .m_apb_prdata(u_top.apb_prdata), .m_apb_pready(u_top.apb_pready), .m_apb_pslverr(u_top.apb_pslverr)
    );

    // Bind APB CSR SVA
    bind u_top.u_csr apb_csr_sva bind_apb_sva (
        .pclk(pclk), .prst_n(prst_n),
        .paddr(paddr), .penable(penable), .pwrite(pwrite), .pwdata(pwdata),
        .pselx(pselx), .pready(pready), .prdata(prdata), .pslverr(pslverr),
        .pstrb(pstrb), .status_reg(status_reg)
    );

    // Clock Gen
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk; // 100MHz clock (10ns period)
    end

    // TASK: AXI Write with dleay variable inputs to simulate a WAIT state for AXI Manager 
    task axi_write(
        input logic [AXI_ADDR_WIDTH-1:0] addr, 
        input logic [AXI_DATA_WIDTH-1:0] data,
        input int w_delay, // Cycles to wait before asserting wvalid
        input int b_delay  // Cycles to wait before asserting bready
    );
        begin
            s_axi_awaddr  = addr;
            s_axi_awvalid = 1'b1;
            s_axi_wvalid  = 1'b0;
            s_axi_bready  = 1'b0;

            // Wait for handshake
            wait (s_axi_awready == 1'b1);
            @(posedge aclk);
            s_axi_awvalid = 1'b0; 

            // Applies delay logic for W Channel
            repeat(w_delay) @(posedge aclk);

            // Drive W Channel
            s_axi_wdata   = data;
            s_axi_wstrb   = 4'b1111; 
            s_axi_wvalid  = 1'b1;

            // Wait for handshake
            wait (s_axi_wready == 1'b1);
            @(posedge aclk);
            s_axi_wvalid = 1'b0;  

            wait (s_axi_bvalid == 1'b1);
            
            // Apply delay logic for B Channel
            repeat(b_delay) @(posedge aclk);
            
            s_axi_bready = 1'b1;

            // Complete the Handshake
            @(posedge aclk);
            #1;
            s_axi_bready = 1'b0;
            
            $display("[%0t] AXI Write Completed: Addr = 0x%0h, Data = 0x%0h, Resp = %0b", 
                     $time, addr, data, s_axi_bresp);
        end
    endtask

    // TASK: AXI Read with delay variable inputs to simulate a WAIT state for the AXI Manager
    task axi_read(
        input  logic [AXI_ADDR_WIDTH-1:0] addr, 
        output logic [AXI_DATA_WIDTH-1:0] read_data,
        output axi_resp_e                 read_resp,
        input  int                        r_delay // Cycles to wait before asserting rready
    );
        begin
            s_axi_araddr  = addr;
            s_axi_arvalid = 1'b1;
            s_axi_rready  = 1'b0; 

            // Wait for handshake
            wait (s_axi_arready == 1'b1);
            @(posedge aclk);
            s_axi_arvalid = 1'b0; 

            wait (s_axi_rvalid == 1'b1);
            
            repeat(r_delay) @(posedge aclk);
            
            s_axi_rready = 1'b1;
            @(posedge aclk);
            
            #1;
            read_data = s_axi_rdata;
            read_resp = s_axi_rresp;
            s_axi_rready = 1'b0;
            
            $display("[%0t] AXI Read Completed: Addr = 0x%0h, Data = 0x%0h, Resp = %0b", 
                     $time, addr, read_data, read_resp);
        end
    endtask


    // The following are the Test cases created by GEMINI to verify the bridge.
    //

    // =========================================================
    // Main Test Sequence
    // =========================================================
    initial begin
        // Initialize AXI4-Lite Manager signals
        s_axi_awaddr  = '0;
        s_axi_awvalid = '0;
        s_axi_wdata   = '0;
        s_axi_wstrb   = '0;
        s_axi_wvalid  = '0;
        s_axi_bready  = '0;
        s_axi_araddr  = '0;
        s_axi_arvalid = '0;
        s_axi_rready  = '0;
        
        // Assert Reset
        $display("\n[%0t] SYSTEM: Asserting Reset...", $time);
        arst_n = 0;
        #20;
        arst_n = 1;
        $display("[%0t] SYSTEM: Reset Released.\n", $time);
        #20;

        // ---------------------------------------------------------
        // TEST 1: Zero-Delay Write and Read (TEMP @ 0x0C)
        // Baseline 0-wait-state write and readback
        // ---------------------------------------------------------
        $display("[%0t] TEST 1: Zero-Delay Write and Read (TEMP 0x0C)", $time);
        axi_write(32'h0000_000C, 32'h1111_1111, 0, 0);
        if (s_axi_bresp != AXI_RESP_OKAY)
            $display(" -> FAIL: Write returned unexpected resp %0b", s_axi_bresp);

        axi_read(32'h0000_000C, readback_data, readback_status, 0);
        if (readback_data == 32'h1111_1111 && readback_status == AXI_RESP_OKAY)
            $display(" -> PASS: Data and responses match expected.\n");
        else
            $display(" -> FAIL: Expected 0x11111111 (OKAY), Got 0x%0h (Resp %0b)\n",
                     readback_data, readback_status);
        #40;

        // ---------------------------------------------------------
        // TEST 2: Staggered Write Channels (CONFIG @ 0x08)
        // Delays WVALID by 3 cycles and BREADY by 2 cycles
        // ---------------------------------------------------------
        $display("[%0t] TEST 2: Staggered Write - AW/W Decoupling (CONFIG 0x08)", $time);
        axi_write(32'h0000_0008, 32'h2222_2222, 3, 2);
        if (s_axi_bresp != AXI_RESP_OKAY)
            $display(" -> FAIL: Write returned unexpected resp %0b", s_axi_bresp);

        axi_read(32'h0000_0008, readback_data, readback_status, 0);
        if (readback_data == 32'h2222_2222 && readback_status == AXI_RESP_OKAY)
            $display(" -> PASS: Decoupled write to CONFIG succeeded.\n");
        else
            $display(" -> FAIL: Expected 0x22222222 (OKAY), Got 0x%0h (Resp %0b)\n",
                     readback_data, readback_status);
        #40;

        // ---------------------------------------------------------
        // TEST 3: Backpressured Read Response (TEMP @ 0x0C)
        // Manager stalls RREADY for 5 cycles to test payload stability
        // ---------------------------------------------------------
        $display("[%0t] TEST 3: Backpressured Read - RREADY Delay (TEMP 0x0C)", $time);
        axi_write(32'h0000_000C, 32'h3333_3333, 0, 0);
        if (s_axi_bresp != AXI_RESP_OKAY)
            $display(" -> FAIL: Write returned unexpected resp %0b", s_axi_bresp);

        axi_read(32'h0000_000C, readback_data, readback_status, 5);
        if (readback_data == 32'h3333_3333 && readback_status == AXI_RESP_OKAY)
            $display(" -> PASS: Read payload held stable during backpressure.\n");
        else
            $display(" -> FAIL: Expected 0x33333333 (OKAY), Got 0x%0h (Resp %0b)\n",
                     readback_data, readback_status);
        #40;

        // ---------------------------------------------------------
        // TEST 4: Negative Test - Unmapped Address Write (0x10)
        // Verifies CSR asserts pslverr and bridge returns SLVERR
        // ---------------------------------------------------------
        $display("[%0t] TEST 4: Negative Test - Unmapped Address Write (0x10)", $time);
        axi_write(32'h0000_0010, 32'hBADC_0DE0, 0, 0);
        if (s_axi_bresp == AXI_RESP_SLVERR)
            $display(" -> PASS: Bridge returned AXI_RESP_SLVERR for unmapped write.\n");
        else
            $display(" -> FAIL: Expected AXI_RESP_SLVERR, Got %0b\n", s_axi_bresp);
        #40;

        // ---------------------------------------------------------
        // TEST 5: Negative Test - Unmapped Address Read (0x10)
        // Verifies unmapped read returns SLVERR on s_axi_rresp
        // ---------------------------------------------------------
        $display("[%0t] TEST 5: Negative Test - Unmapped Address Read (0x10)", $time);
        axi_read(32'h0000_0010, readback_data, readback_status, 2);
        if (readback_status == AXI_RESP_SLVERR)
            $display(" -> PASS: Bridge returned AXI_RESP_SLVERR for unmapped read.\n");
        else
            $display(" -> FAIL: Expected AXI_RESP_SLVERR, Got %0b\n", readback_status);
        #40;

        // ---------------------------------------------------------
        // TEST 6: Negative Test - Read-Only Register Write (STATUS @ 0x04)
        // Verifies write returns SLVERR and STATUS is not overwritten
        // ---------------------------------------------------------
        $display("[%0t] TEST 6: Negative Test - Read-Only Register Write (STATUS 0x04)", $time);
        axi_write(32'h0000_0004, 32'hFFFF_FFFF, 1, 1);
        if (s_axi_bresp == AXI_RESP_SLVERR)
            $display(" -> PASS: Bridge rejected write to read-only STATUS register.");
        else
            $display(" -> FAIL: Expected AXI_RESP_SLVERR, Got %0b", s_axi_bresp);

        axi_read(32'h0000_0004, readback_data, readback_status, 0);
        if (readback_data != 32'hFFFF_FFFF && readback_status == AXI_RESP_OKAY)
            $display(" -> PASS: STATUS readback intact (0x%0h).\n", readback_data);
        else
            $display(" -> FAIL: STATUS modified or read failed (0x%0h, Resp %0b)\n",
                     readback_data, readback_status);
        #40;

        // ---------------------------------------------------------
        // TEST 7: Back-to-Back Recovery (CTRL @ 0x00)
        // Verifies valid write and read return OKAY immediately after errors
        // ---------------------------------------------------------
        $display("[%0t] TEST 7: Back-to-Back Recovery (CTRL 0x00)", $time);
        axi_write(32'h0000_0000, 32'hAAAA_BBBB, 0, 0);
        if (s_axi_bresp != AXI_RESP_OKAY)
            $display(" -> FAIL: Recovery write returned unexpected resp %0b", s_axi_bresp);

        axi_read(32'h0000_0000, readback_data, readback_status, 2);
        if (readback_data == 32'hAAAA_BBBB && readback_status == AXI_RESP_OKAY)
            $display(" -> PASS: System recovered with clean OKAY write and read.\n");
        else
            $display(" -> FAIL: Expected 0xAAAABBBB (OKAY), Got 0x%0h (Resp %0b)\n",
                     readback_data, readback_status);

        $display("\n[%0t] SYSTEM: All Verification Scenarios Complete.", $time);
        #50;
        $finish;
    end

endmodule