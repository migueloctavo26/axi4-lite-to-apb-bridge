`timescale 1ns/1ps

import axi_to_apb_bridge_pkg::*;

module axi_to_apb_bridge_sva (
    // Global Clock & Reset
    input logic                        aclk,
    input logic                        arst_n,

    // AXI Read Address Channel (AR)
    input logic [AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
    input logic                        s_axi_arvalid,
    input logic                        s_axi_arready,

    // AXI Read Data Channel (R)
    input logic                        s_axi_rready,
    input logic [AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    input axi_resp_e                   s_axi_rresp,
    input logic                        s_axi_rvalid,

    // AXI Write Address Channel (AW)
    input logic [AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input logic                        s_axi_awvalid,
    input logic                        s_axi_awready,

    // AXI Write Data Channel (W)
    input logic [AXI_DATA_WIDTH-1:0]   s_axi_wdata,
    input logic [AXI_STRB_WIDTH-1:0]   s_axi_wstrb,
    input logic                        s_axi_wvalid,
    input logic                        s_axi_wready,

    // AXI Write Response Channel (B)
    input logic                        s_axi_bready,
    input axi_resp_e                   s_axi_bresp,
    input logic                        s_axi_bvalid,

    // APB Requester Interface
    input logic [PADDR_WIDTH-1:0]      m_apb_paddr,
    input logic                        m_apb_penable,
    input logic                        m_apb_pwrite,
    input logic [PSTRB_WIDTH-1:0]      m_apb_pstrb,
    input logic [PDATA_WIDTH-1:0]      m_apb_pwdata,
    input logic                        m_apb_pselx,
    input logic [PDATA_WIDTH-1:0]      m_apb_prdata,
    input logic                        m_apb_pready,
    input logic                        m_apb_pslverr
);

// Immediate SVA: Checks that required signals get deasserted w arst_n
reset_required_signals_check: assert final (!arst_n || (!s_axi_awready && !s_axi_wready && 
    !s_axi_arready && !s_axi_bvalid && !s_axi_rvalid && !m_apb_pselx && !m_apb_penable))
    else $error("[RESET VIOLATION]: Signals did NOT get deasserted with reset.");

// Concurrent SVA:
// Checks that the deasserted signals stay deasserted until after arst_n is HIGH  and at a rising aclk
property reset_check;
    @(posedge aclk) $past(!arst_n) |-> (!s_axi_awready && !s_axi_wready && 
    !s_axi_arready && !s_axi_bvalid && !s_axi_rvalid && !m_apb_pselx && !m_apb_penable);
endproperty
reset_check_a: assert property (reset_check)
    else $error("[RESET VIOLATION]: Signals were NOT asserted before the first clock edge after reset is asserted.");


// Checks that the AXI Handshake procedures are being followed for the AW Channel
property axi_awvalid_stable_check;
    @(posedge aclk) disable iff (!arst_n)
    (s_axi_awvalid && !s_axi_awready) |=> s_axi_awvalid;
endproperty
axi_awvalid_stable_check_a: assert property (axi_awvalid_stable_check)
    else $error("[AXI Violation]: awvalid dropped before handshake from awready.");

// Chekcs that the AXI Handshake procedures are being followed for the W Channel
property axi_wvalid_stable_check;
    @(posedge aclk) disable iff (!arst_n)
    (s_axi_wvalid && !s_axi_wready) |=> s_axi_wvalid;
endproperty
axi_wvalid_stable_check_a: assert property (axi_wvalid_stable_check)
    else $error("[AXI Violation]: wvalid dropped before the handshake from wready.");

// Checks that the AXI Handshake procedures are beign followed for the AR Channel
property axi_arvalid_stable_check;
    @(posedge aclk) disable iff (!arst_n)
    (s_axi_arvalid && !s_axi_arready) |=> s_axi_arvalid;
endproperty
axi_arvalid_stable_check_a: assert property (axi_arvalid_stable_check)
    else $error("[AXI VIOLATION]: arvalid dropped before the handshake from arready.");


// Checks that there are NO outstanding transactions since AXI4-Lite does not support it
property axi_no_outstanding_addr_check;
    @(posedge aclk) disable iff (!arst_n)
    m_apb_pselx |-> (!s_axi_awready &&!s_axi_arready);
endproperty
axi_no_outstanding_addr_check_a: assert property(axi_no_outstanding_addr_check)
    else $error("[AXI Violation]: Bridge took new address while APB ACCESS State.");

// Checks address stability throughout transaction for VALID before READY Handshake
property axi_awaddr_stability_check;
    @(posedge aclk) disable iff(!arst_n)
    (s_axi_awvalid && !s_axi_awready) |=> $stable(s_axi_awaddr);
endproperty
axi_awaddr_stability_check_a: assert property (axi_awaddr_stability_check)
    else $error("[AXI VIOLATION]: awaddr changed before the awready handshake.");

// Checks that during an APB Read, pstrb is deasserted
property apb_read_pstrb_deasserted_check;
    @(posedge aclk) disable iff (!arst_n)
    (m_apb_pselx && !m_apb_pwrite) |-> (m_apb_pstrb == '0);
endproperty
apb_read_pstrb_deasserted_check_a: assert property (apb_read_pstrb_deasserted_check)
    else $error("[APB Violation]: pstrb is not deasserted during a Read transaction.");

// Checks that Error Translations from APB to AXI is working correctly for WRITE transation
property apb_write_error_translation_check;
    @(posedge aclk) disable iff (!arst_n)
    (m_apb_pselx && m_apb_penable && m_apb_pready && m_apb_pslverr && m_apb_pwrite) |=> 
    (s_axi_bvalid && (s_axi_bresp == AXI_RESP_SLVERR));
endproperty
apb_write_error_translation_check_a: assert property(apb_write_error_translation_check)
    else $error("[Bridge Violation]: APB write pslverr was not translated onto AXI bresp.");

// Checks that Error Translations from APB to AXI is working correctly for READ transaction
property apb_read_error_translation_check;
    @(posedge aclk) disable iff (!arst_n)
    (m_apb_pselx && m_apb_penable && m_apb_pready && m_apb_pslverr && !m_apb_pwrite) |=> 
    (s_axi_rvalid && (s_axi_rresp == AXI_RESP_SLVERR));
endproperty
apb_read_error_translation_check_a: assert property(apb_read_error_translation_check)
    else $error("[Bridge Violation]: APB read pslverr was not translated onto AXI rresp.");

endmodule : axi_to_apb_bridge_sva
