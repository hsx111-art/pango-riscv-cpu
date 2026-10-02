`timescale 1ns/1ps

module tb_tcm_basic #(
    parameter ENABLE_BRANCH_PREDICTOR = 0
);

    reg         clk_i;
    reg         rst_i;
    reg         rst_cpu_i;
    reg [31:0]  intr_i;

    reg         axi_i_awready_i;
    reg         axi_i_wready_i;
    reg         axi_i_bvalid_i;
    reg [1:0]   axi_i_bresp_i;
    reg         axi_i_arready_i;
    reg         axi_i_rvalid_i;
    reg [31:0]  axi_i_rdata_i;
    reg [1:0]   axi_i_rresp_i;

    reg         axi_t_awvalid_i;
    reg [31:0]  axi_t_awaddr_i;
    reg [3:0]   axi_t_awid_i;
    reg [7:0]   axi_t_awlen_i;
    reg [1:0]   axi_t_awburst_i;
    reg         axi_t_wvalid_i;
    reg [31:0]  axi_t_wdata_i;
    reg [3:0]   axi_t_wstrb_i;
    reg         axi_t_wlast_i;
    reg         axi_t_bready_i;
    reg         axi_t_arvalid_i;
    reg [31:0]  axi_t_araddr_i;
    reg [3:0]   axi_t_arid_i;
    reg [7:0]   axi_t_arlen_i;
    reg [1:0]   axi_t_arburst_i;
    reg         axi_t_rready_i;

    wire        axi_i_awvalid_o;
    wire [31:0] axi_i_awaddr_o;
    wire        axi_i_wvalid_o;
    wire [31:0] axi_i_wdata_o;
    wire [3:0]  axi_i_wstrb_o;
    wire        axi_i_bready_o;
    wire        axi_i_arvalid_o;
    wire [31:0] axi_i_araddr_o;
    wire        axi_i_rready_o;
    wire        axi_t_awready_o;
    wire        axi_t_wready_o;
    wire        axi_t_bvalid_o;
    wire [1:0]  axi_t_bresp_o;
    wire [3:0]  axi_t_bid_o;
    wire        axi_t_arready_o;
    wire        axi_t_rvalid_o;
    wire [31:0] axi_t_rdata_o;
    wire [1:0]  axi_t_rresp_o;
    wire [3:0]  axi_t_rid_o;
    wire        axi_t_rlast_o;

    integer index;
    reg     pass_seen;

    riscv_tcm_top #(
        .BOOT_VECTOR(32'h00002000),
        .TCM_MEM_BASE(32'h00000000),
        .MEM_CACHE_ADDR_MIN(32'h00000000),
        .MEM_CACHE_ADDR_MAX(32'hffffffff),
        .ENABLE_BRANCH_PREDICTOR(ENABLE_BRANCH_PREDICTOR)
    ) dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .rst_cpu_i(rst_cpu_i),
        .axi_i_awready_i(axi_i_awready_i),
        .axi_i_wready_i(axi_i_wready_i),
        .axi_i_bvalid_i(axi_i_bvalid_i),
        .axi_i_bresp_i(axi_i_bresp_i),
        .axi_i_arready_i(axi_i_arready_i),
        .axi_i_rvalid_i(axi_i_rvalid_i),
        .axi_i_rdata_i(axi_i_rdata_i),
        .axi_i_rresp_i(axi_i_rresp_i),
        .axi_t_awvalid_i(axi_t_awvalid_i),
        .axi_t_awaddr_i(axi_t_awaddr_i),
        .axi_t_awid_i(axi_t_awid_i),
        .axi_t_awlen_i(axi_t_awlen_i),
        .axi_t_awburst_i(axi_t_awburst_i),
        .axi_t_wvalid_i(axi_t_wvalid_i),
        .axi_t_wdata_i(axi_t_wdata_i),
        .axi_t_wstrb_i(axi_t_wstrb_i),
        .axi_t_wlast_i(axi_t_wlast_i),
        .axi_t_bready_i(axi_t_bready_i),
        .axi_t_arvalid_i(axi_t_arvalid_i),
        .axi_t_araddr_i(axi_t_araddr_i),
        .axi_t_arid_i(axi_t_arid_i),
        .axi_t_arlen_i(axi_t_arlen_i),
        .axi_t_arburst_i(axi_t_arburst_i),
        .axi_t_rready_i(axi_t_rready_i),
        .intr_i(intr_i),
        .axi_i_awvalid_o(axi_i_awvalid_o),
        .axi_i_awaddr_o(axi_i_awaddr_o),
        .axi_i_wvalid_o(axi_i_wvalid_o),
        .axi_i_wdata_o(axi_i_wdata_o),
        .axi_i_wstrb_o(axi_i_wstrb_o),
        .axi_i_bready_o(axi_i_bready_o),
        .axi_i_arvalid_o(axi_i_arvalid_o),
        .axi_i_araddr_o(axi_i_araddr_o),
        .axi_i_rready_o(axi_i_rready_o),
        .axi_t_awready_o(axi_t_awready_o),
        .axi_t_wready_o(axi_t_wready_o),
        .axi_t_bvalid_o(axi_t_bvalid_o),
        .axi_t_bresp_o(axi_t_bresp_o),
        .axi_t_bid_o(axi_t_bid_o),
        .axi_t_arready_o(axi_t_arready_o),
        .axi_t_rvalid_o(axi_t_rvalid_o),
        .axi_t_rdata_o(axi_t_rdata_o),
        .axi_t_rresp_o(axi_t_rresp_o),
        .axi_t_rid_o(axi_t_rid_o),
        .axi_t_rlast_o(axi_t_rlast_o)
    );

    always #5 clk_i = ~clk_i;

    initial begin
        clk_i = 1'b0;
        rst_i = 1'b1;
        rst_cpu_i = 1'b1;
        intr_i = 32'b0;

        axi_i_awready_i = 1'b0;
        axi_i_wready_i = 1'b0;
        axi_i_bvalid_i = 1'b0;
        axi_i_bresp_i = 2'b0;
        axi_i_arready_i = 1'b0;
        axi_i_rvalid_i = 1'b0;
        axi_i_rdata_i = 32'b0;
        axi_i_rresp_i = 2'b0;

        axi_t_awvalid_i = 1'b0;
        axi_t_awaddr_i = 32'b0;
        axi_t_awid_i = 4'b0;
        axi_t_awlen_i = 8'b0;
        axi_t_awburst_i = 2'b0;
        axi_t_wvalid_i = 1'b0;
        axi_t_wdata_i = 32'b0;
        axi_t_wstrb_i = 4'b0;
        axi_t_wlast_i = 1'b0;
        axi_t_bready_i = 1'b0;
        axi_t_arvalid_i = 1'b0;
        axi_t_araddr_i = 32'b0;
        axi_t_arid_i = 4'b0;
        axi_t_arlen_i = 8'b0;
        axi_t_arburst_i = 2'b0;
        axi_t_rready_i = 1'b0;
        pass_seen = 1'b0;

        for (index = 0; index < 16384; index = index + 1)
            dut.u_tcm.u_ram.ram[index] = 32'b0;
        $readmemh("basic.memh", dut.u_tcm.u_ram.ram);

        repeat (2) @(posedge clk_i);
        rst_i = 1'b0;
        rst_cpu_i = 1'b0;
        $display("TCM image loaded; CPU reset released at %0t", $time);
    end

    // The core's existing simulation CSR issues $finish. Sample the same
    // writeback request one half-cycle earlier to classify the result.
    always @(negedge clk_i) begin
        if (dut.u_core.u_csr.u_csrfile.csr_waddr_i == 12'h7b2 &&
            dut.u_core.u_csr.u_csrfile.csr_wdata_i[31:24] == 8'h00) begin
            if (dut.u_core.u_csr.u_csrfile.csr_wdata_i[7:0] == 8'h00) begin
                pass_seen = 1'b1;
                $display("BASELINE_B_PASS");
                $finish;
            end
            else begin
                $display("BASELINE_B_FAIL: software exit code %0d", dut.u_core.u_csr.u_csrfile.csr_wdata_i[7:0]);
                $fatal(1, "software requested a non-zero simulation exit");
            end
        end
    end

    initial begin
        repeat (1000000) @(posedge clk_i);
        if (!pass_seen) begin
            $display("BASELINE_B_FAIL: timeout waiting for CSR_DSCRATCH exit");
            $fatal(1, "TCM CPU did not complete the image");
        end
    end

endmodule
