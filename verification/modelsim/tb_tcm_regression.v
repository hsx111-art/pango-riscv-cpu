`timescale 1ns/1ps

module tb_tcm_regression;

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

    reg [2047:0] memh_path;
    reg [1023:0] test_name;
    integer      max_cycles;
    integer      cycle_count;
    integer      index;
    reg          pass_seen;
    reg          fail_seen;
    integer      irq_cycle;
    integer      retired_count;
    real         cpi_value;

    riscv_tcm_top #(
        .BOOT_VECTOR(32'h00002000),
        .TCM_MEM_BASE(32'h00000000),
        .MEM_CACHE_ADDR_MIN(32'h00000000),
        .MEM_CACHE_ADDR_MAX(32'hffffffff)
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
        if (!$value$plusargs("MEMH=%s", memh_path))
            $fatal(1, "MEMH plusarg is required");
        if (!$value$plusargs("TESTNAME=%s", test_name))
            $fatal(1, "TESTNAME plusarg is required");
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles))
            max_cycles = 1000000;
        if (!$value$plusargs("IRQ_CYCLE=%d", irq_cycle))
            irq_cycle = -1;

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
        cycle_count = 0;
        retired_count = 0;
        pass_seen = 1'b0;
        fail_seen = 1'b0;

        for (index = 0; index < 16384; index = index + 1)
            dut.u_tcm.u_ram.ram[index] = 32'b0;
        $readmemh(memh_path, dut.u_tcm.u_ram.ram);

        repeat (2) @(posedge clk_i);
        rst_i = 1'b0;
        rst_cpu_i = 1'b0;
        $display("TCM image loaded for %s; CPU reset released at %0t", test_name, $time);
    end

    // The core's simulation CSR issues $finish on the following clock edge.
    // Sample the writeback request one half-cycle earlier so ModelSim can
    // classify the standard test before the RTL terminates the run.
    always @(negedge clk_i) begin
        if (!rst_i && dut.u_core.u_issue.u_pipe_ctrl.instruction_retired_w)
            retired_count = retired_count + 1;
        if (!rst_i && irq_cycle >= 0) begin
            if (cycle_count == irq_cycle)
                intr_i[0] = 1'b1;
            else if (cycle_count == (irq_cycle + 1))
                intr_i[0] = 1'b0;
        end
        if (!rst_i && dut.u_core.u_csr.u_csrfile.csr_waddr_i == 12'h7b2) begin
            case (dut.u_core.u_csr.u_csrfile.csr_wdata_i[31:24])
                8'h01: begin
                    if (dut.u_core.u_csr.u_csrfile.csr_wdata_i[7:0] == "P") begin
                        pass_seen = 1'b1;
                        $display("MODELSIM_TEST_PASS");
                    end
                    else if (dut.u_core.u_csr.u_csrfile.csr_wdata_i[7:0] == "F") begin
                        fail_seen = 1'b1;
                        $display("MODELSIM_TEST_FAIL: software reported failure");
                        $fatal(1, "standard test reported FAIL");
                    end
                end
                8'h00: begin
                    if (fail_seen || !pass_seen) begin
                        $display("MODELSIM_TEST_FAIL: exit before PASS");
                        $fatal(1, "standard test exited without PASS");
                    end
                    if (dut.u_core.u_csr.u_csrfile.csr_minstret_q != 0)
                        cpi_value = dut.u_core.u_csr.u_csrfile.csr_mcycle_q * 1.0 /
                                    dut.u_core.u_csr.u_csrfile.csr_minstret_q;
                    else
                        cpi_value = 0.0;
                    $display("MODELSIM_METRICS cycles=%0d retired=%0d retired_probe=%0d mcycle=%08x minstret=%08x cpi=%0.6f", cycle_count, dut.u_core.u_csr.u_csrfile.csr_minstret_q, retired_count, dut.u_core.u_csr.u_csrfile.csr_mcycle_q, dut.u_core.u_csr.u_csrfile.csr_minstret_q, cpi_value);
                    $display("MODELSIM_TEST_COMPLETE");
                    $finish;
                end
            endcase
        end
    end

    initial begin
        forever begin
            @(posedge clk_i);
            if (!rst_i) begin
                cycle_count = cycle_count + 1;
                if (cycle_count >= max_cycles) begin
                    $display("MODELSIM_TEST_FAIL: timeout after %0d cycles", max_cycles);
                    $fatal(1, "TCM CPU did not complete the image");
                end
            end
        end
    end

endmodule
