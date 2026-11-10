/*
* The AXI4-lite to APB4 Bridge will be designed according to 
* AMBA APB4 Specifications and AMBA AXI Specifications.
*
* The module will handle translating AXI4-lite operations
* into APB4 operations for the CSR Completer.
*/

import axi_to_apb_bridge_pkg::*;

module axi_to_apb_bridge (
    // Global Clock and Active LOW Reset 
    input  logic                        aclk,
    input  logic                        arst_n,

    // The following input/output ports will have the prefixes for:
    // s_ (Subordinate for AXI) and m_ (Manager/Requester for APB)

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
    output logic                        s_axi_bvalid,
    
    // APB Requester Interface
    input  logic [PDATA_WIDTH-1:0]      m_apb_prdata,
    input  logic                        m_apb_pready,
    input  logic                        m_apb_pslverr,     
    output logic [PADDR_WIDTH-1:0]      m_apb_paddr,
    output logic                        m_apb_penable,
    output logic                        m_apb_pwrite,
    output logic [PSTRB_WIDTH-1:0]      m_apb_pstrb,
    output logic [PDATA_WIDTH-1:0]      m_apb_pwdata,
    output logic                        m_apb_pselx
);

    // Internal registers to hold necessary AXI Values
    logic [AXI_DATA_WIDTH-1:0]  axi_data;
    logic [AXI_STRB_WIDTH-1:0]  axi_strb;
    logic [AXI_ADDR_WIDTH-1:0]  axi_aw_reg;
    logic [AXI_ADDR_WIDTH-1:0]  axi_ar_reg;

    // Control Flags
    logic                       aw_flag, ar_flag, w_flag;
    logic                       is_read, is_write;

    // FSM for APB4 Transactions
    apb_state_e                 current_state, next_state;


    // (AW) Transaction
    always_ff @(posedge aclk or negedge arst_n) begin
        if (!arst_n) begin
            s_axi_awready  <= '0;
            aw_flag        <= '0;
            axi_aw_reg     <= '0;
        end
        else begin
            if (s_axi_awvalid && !s_axi_awready && !aw_flag && !is_write && !is_read) begin
                s_axi_awready  <= '1;
                aw_flag        <= '1;
                axi_aw_reg     <= s_axi_awaddr;
            end
            else begin
                s_axi_awready  <= '0;
                if (current_state == APB_ACCESS && m_apb_pready && is_write) begin
                    aw_flag    <= '0;
                end
            end
        end
    end 

    // (W) Transaction
    always_ff @(posedge aclk or negedge arst_n) begin
        if (!arst_n) begin
            s_axi_wready   <= '0;
            w_flag         <= '0;
            axi_data       <= '0;
            axi_strb       <= '0;
        end
        else begin
            if (s_axi_wvalid && !s_axi_wready && !w_flag && !is_write && !is_read) begin
                s_axi_wready   <= '1;
                w_flag         <= '1;
                axi_data       <= s_axi_wdata;
                axi_strb       <= s_axi_wstrb;
            end
            else begin
                s_axi_wready   <= '0;
                if (current_state == APB_ACCESS && m_apb_pready && is_write) begin 
                    w_flag     <= '0;
                end
            end
        end
    end

    // (AR) Transaction
    always_ff @(posedge aclk or negedge arst_n) begin
        if (!arst_n) begin
            s_axi_arready <= 1'b0;
            ar_flag       <= 1'b0;
            axi_ar_reg    <= '0;
        end else begin
            if (s_axi_arvalid && !s_axi_arready && !ar_flag && !aw_flag && !w_flag && !is_write && !is_read) begin
                s_axi_arready <= 1'b1;
                ar_flag       <= 1'b1;
                axi_ar_reg    <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
                if (current_state == APB_ACCESS && m_apb_pready && is_read) begin
                    ar_flag   <= 1'b0;
                end
            end
        end        
    end

    // Transaction triggers
    assign is_write = (aw_flag && w_flag);
    assign is_read  = ar_flag;

    // APB FSM
    always_ff @(posedge aclk or negedge arst_n) begin
        if (!arst_n) begin
            current_state <= APB_IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            APB_IDLE: begin
                if (is_write || is_read) begin
                    next_state = APB_SETUP;
                end
            end

            APB_SETUP: begin
                next_state = APB_ACCESS;
            end

            APB_ACCESS: begin
                if (m_apb_pready) begin
                    next_state = APB_IDLE;
                end
            end

            default: next_state = APB_IDLE;
        endcase
    end

    // SIgnal Generation/Handling for both APB and AXI
    always_ff @(posedge aclk or negedge arst_n) begin
        if(!arst_n) begin
            m_apb_pselx        <= 1'b0;
            m_apb_penable      <= 1'b0;
            m_apb_pwrite       <= 1'b0;
            m_apb_paddr        <= '0;
            m_apb_pwdata       <= '0;
            m_apb_pstrb        <= '0;
            
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= AXI_RESP_OKAY;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= AXI_RESP_OKAY;
            s_axi_rdata  <= '0;
        end
        else begin
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= '0;
            end
            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= '0;
            end

case (next_state)
                APB_IDLE: begin
                    m_apb_pselx     <= '0;
                    m_apb_penable   <= '0;
                end

                APB_SETUP: begin
                    m_apb_pselx     <= '1;
                    m_apb_penable   <= '0;
                    m_apb_paddr     <= is_write ? axi_aw_reg : axi_ar_reg;

                    if (is_write) begin
                        m_apb_pwrite    <= '1;
                        m_apb_pwdata    <= axi_data;
                        m_apb_pstrb     <= axi_strb;
                    end
                    else begin
                        m_apb_pwrite    <= '0;
                        m_apb_pwdata    <= '0;
                        m_apb_pstrb     <= '0;
                    end
                end

                APB_ACCESS: begin
                    m_apb_penable <= 1'b1;
                end
                
                default: begin
                    m_apb_pselx     <= '0;
                    m_apb_penable   <= '0;
                end
            endcase

            if (current_state == APB_ACCESS && m_apb_pready) begin
                if (is_write) begin
                    s_axi_bvalid <= '1;
                    s_axi_bresp  <= m_apb_pslverr ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
                end 
                else if (is_read) begin
                    s_axi_rvalid <= '1;
                    s_axi_rdata  <= m_apb_prdata;
                    s_axi_rresp  <= m_apb_pslverr ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
                end
            end
        end
    end
endmodule : axi_to_apb_bridge