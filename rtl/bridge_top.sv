/*
- AXI4-Lite to APB4 CSR Subsystem Top Module
- Encapsulates the protocol bridge and the custom CSR Completer.
- Exposes only the AXI4-Lite interface to the SoC interconnect.
*
* Gemini was used to just connect everythign together.
*/

import axi_to_apb_bridge_pkg::*;

module bridge_top (
    // Global Clock and Active LOW Reset 
    input  logic                        aclk,
    input  logic                        arst_n,

    // AXI Read Address Channel     (AR)
    input  logic [AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic                        s_axi_arvalid,
    output logic                        s_axi_arready,

    // AXI Read Data Channel        (R)
    input  logic                        s_axi_rready,
    output logic [AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    output axi_resp_e                   s_axi_rresp,
    output logic                        s_axi_rvalid,

    // AXI Write Address Channel    (AW)
    input  logic [AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic                        s_axi_awvalid,
    output logic                        s_axi_awready,

    // AXI Write Data Channel       (W)
    input  logic [AXI_DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [AXI_STRB_WIDTH-1:0]   s_axi_wstrb,
    input  logic                        s_axi_wvalid,
    output logic                        s_axi_wready,

    // AXI Write Response Channel   (B)
    input  logic                        s_axi_bready,
    output axi_resp_e                   s_axi_bresp,
    output logic                        s_axi_bvalid
);

    // =========================================================================
    // Internal APB Traces (The physical wires connecting Bridge to CSR)
    // =========================================================================
    logic [PADDR_WIDTH-1:0]             apb_paddr;
    logic                               apb_penable;
    logic                               apb_pwrite;
    logic [PSTRB_WIDTH-1:0]             apb_pstrb;
    logic [PDATA_WIDTH-1:0]             apb_pwdata;
    logic                               apb_pselx;
    logic [PDATA_WIDTH-1:0]             apb_prdata;
    logic                               apb_pready;
    logic                               apb_pslverr;

    // =========================================================================
    // Manager: AXI-to-APB Bridge
    // =========================================================================
    axi_to_apb_bridge u_bridge (
        .aclk           (aclk),
        .arst_n         (arst_n),
        
        // AXI Ports (Routed directly to top-level pins)
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
        .s_axi_bvalid   (s_axi_bvalid),

        // APB Requester Ports (Routed to internal traces)
        .m_apb_paddr    (apb_paddr),
        .m_apb_penable  (apb_penable),
        .m_apb_pwrite   (apb_pwrite),
        .m_apb_pstrb    (apb_pstrb),
        .m_apb_pwdata   (apb_pwdata),
        .m_apb_pselx    (apb_pselx),
        .m_apb_prdata   (apb_prdata),
        .m_apb_pready   (apb_pready),
        .m_apb_pslverr  (apb_pslverr)
    );

    // =========================================================================
    // Completer: APB CSR Module
    // =========================================================================
    apb_csr u_csr (
        // Map global AXI clock/reset to the APB clock/reset domains
        .pclk           (aclk),
        .prst_n         (arst_n),

        // APB Subordinate Ports (Routed from internal traces)
        .paddr          (apb_paddr),
        .penable        (apb_penable),
        .pwrite         (apb_pwrite),
        .pstrb          (apb_pstrb),
        .pwdata         (apb_pwdata),
        .pselx          (apb_pselx), // Updated to match your exact pselx naming
        
        .prdata         (apb_prdata),
        .pready         (apb_pready),
        .pslverr        (apb_pslverr)
    );

endmodule : bridge_top