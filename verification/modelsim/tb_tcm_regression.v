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
    integer      profile_issue_count;
    integer      profile_retire_count;
    integer      profile_lsu_stall_count;
    integer      profile_pipe_stall_count;
    integer      profile_div_hold_count;
    integer      profile_csr_hold_count;
    integer      profile_load_count;
    integer      profile_store_count;
    integer      profile_mul_count;
    integer      profile_div_count;
    integer      profile_csr_count;
    integer      profile_branch_count;
    integer      profile_branch_taken_count;
    integer      profile_redirect_count;
    integer      profile_interrupt_count;
    integer      profile_issue_blocked_count;
    reg          workload_profile_active;
    reg          workload_profile_start_seen;
    reg          workload_profile_end_seen;
    integer      workload_profile_start_cycle;
    integer      workload_profile_cycle_count;
    integer      workload_profile_issue_count;
    integer      workload_profile_retire_count;
    integer      workload_profile_lsu_stall_count;
    integer      workload_profile_pipe_stall_count;
    integer      workload_profile_div_hold_count;
    integer      workload_profile_csr_hold_count;
    integer      workload_profile_load_count;
    integer      workload_profile_store_count;
    integer      workload_profile_mul_count;
    integer      workload_profile_div_count;
    integer      workload_profile_csr_count;
    integer      workload_profile_branch_count;
    integer      workload_profile_branch_taken_count;
    integer      workload_profile_redirect_count;
    integer      workload_profile_interrupt_count;
    integer      workload_profile_issue_blocked_count;
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

    wire profile_marker_write =
        (dut.u_core.u_csr.u_csrfile.csr_waddr_i == 12'h7b2);
    wire profile_marker_start =
        profile_marker_write &&
        (dut.u_core.u_csr.u_csrfile.csr_wdata_i[31:24] == 8'h02);
    wire profile_marker_end =
        profile_marker_write &&
        (dut.u_core.u_csr.u_csrfile.csr_wdata_i[31:24] == 8'h03);

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
        profile_issue_count = 0;
        profile_retire_count = 0;
        profile_lsu_stall_count = 0;
        profile_pipe_stall_count = 0;
        profile_div_hold_count = 0;
        profile_csr_hold_count = 0;
        profile_load_count = 0;
        profile_store_count = 0;
        profile_mul_count = 0;
        profile_div_count = 0;
        profile_csr_count = 0;
        profile_branch_count = 0;
        profile_branch_taken_count = 0;
        profile_redirect_count = 0;
        profile_interrupt_count = 0;
        profile_issue_blocked_count = 0;
        workload_profile_active = 1'b0;
        workload_profile_start_seen = 1'b0;
        workload_profile_end_seen = 1'b0;
        workload_profile_start_cycle = 0;
        workload_profile_cycle_count = 0;
        workload_profile_issue_count = 0;
        workload_profile_retire_count = 0;
        workload_profile_lsu_stall_count = 0;
        workload_profile_pipe_stall_count = 0;
        workload_profile_div_hold_count = 0;
        workload_profile_csr_hold_count = 0;
        workload_profile_load_count = 0;
        workload_profile_store_count = 0;
        workload_profile_mul_count = 0;
        workload_profile_div_count = 0;
        workload_profile_csr_count = 0;
        workload_profile_branch_count = 0;
        workload_profile_branch_taken_count = 0;
        workload_profile_redirect_count = 0;
        workload_profile_interrupt_count = 0;
        workload_profile_issue_blocked_count = 0;
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
        if (!rst_i && profile_marker_start) begin
            workload_profile_active = 1'b1;
            workload_profile_start_seen = 1'b1;
            workload_profile_end_seen = 1'b0;
            workload_profile_start_cycle = cycle_count;
            workload_profile_cycle_count = 0;
            workload_profile_issue_count = 0;
            workload_profile_retire_count = 0;
            workload_profile_lsu_stall_count = 0;
            workload_profile_pipe_stall_count = 0;
            workload_profile_div_hold_count = 0;
            workload_profile_csr_hold_count = 0;
            workload_profile_load_count = 0;
            workload_profile_store_count = 0;
            workload_profile_mul_count = 0;
            workload_profile_div_count = 0;
            workload_profile_csr_count = 0;
            workload_profile_branch_count = 0;
            workload_profile_branch_taken_count = 0;
            workload_profile_redirect_count = 0;
            workload_profile_interrupt_count = 0;
            workload_profile_issue_blocked_count = 0;
            $display("MODELSIM_WORKLOAD_PROFILE_START cycle=%0d", cycle_count);
        end
        else if (!rst_i && profile_marker_end && workload_profile_active) begin
            workload_profile_active = 1'b0;
            workload_profile_end_seen = 1'b1;
            workload_profile_cycle_count = cycle_count - workload_profile_start_cycle;
            $display("MODELSIM_WORKLOAD_PROFILE cycles=%0d issue=%0d retire=%0d lsu_stall=%0d pipe_stall=%0d div_hold=%0d csr_hold=%0d load=%0d store=%0d mul=%0d div=%0d csr=%0d branch=%0d branch_taken=%0d redirect=%0d interrupt=%0d issue_blocked=%0d", workload_profile_cycle_count, workload_profile_issue_count, workload_profile_retire_count, workload_profile_lsu_stall_count, workload_profile_pipe_stall_count, workload_profile_div_hold_count, workload_profile_csr_hold_count, workload_profile_load_count, workload_profile_store_count, workload_profile_mul_count, workload_profile_div_count, workload_profile_csr_count, workload_profile_branch_count, workload_profile_branch_taken_count, workload_profile_redirect_count, workload_profile_interrupt_count, workload_profile_issue_blocked_count);
        end
        if (!rst_i) begin
            if (dut.u_core.u_issue.opcode_issue_r && dut.u_core.u_issue.opcode_accept_r)
                profile_issue_count = profile_issue_count + 1;
            if (dut.u_core.u_issue.instruction_retired_o) begin
                retired_count = retired_count + 1;
                profile_retire_count = profile_retire_count + 1;
            end
            if (dut.u_core.u_issue.lsu_stall_i)
                profile_lsu_stall_count = profile_lsu_stall_count + 1;
            if (dut.u_core.u_issue.exec_hold_o)
                profile_pipe_stall_count = profile_pipe_stall_count + 1;
            if (dut.u_core.u_issue.div_pending_q)
                profile_div_hold_count = profile_div_hold_count + 1;
            if (dut.u_core.u_issue.csr_pending_q)
                profile_csr_hold_count = profile_csr_hold_count + 1;
            if (dut.u_core.u_issue.u_pipe_ctrl.load_e1_o)
                profile_load_count = profile_load_count + 1;
            if (dut.u_core.u_issue.u_pipe_ctrl.store_e1_o)
                profile_store_count = profile_store_count + 1;
            if (dut.u_core.u_issue.u_pipe_ctrl.mul_e1_o)
                profile_mul_count = profile_mul_count + 1;
            if (dut.u_core.u_issue.opcode_issue_r && dut.u_core.u_issue.issue_div_w)
                profile_div_count = profile_div_count + 1;
            if (dut.u_core.u_issue.opcode_issue_r && dut.u_core.u_issue.issue_csr_w)
                profile_csr_count = profile_csr_count + 1;
            if (dut.u_core.u_issue.branch_exec_request_i)
                profile_branch_count = profile_branch_count + 1;
            if (dut.u_core.u_issue.branch_exec_is_taken_i)
                profile_branch_taken_count = profile_branch_taken_count + 1;
            if (dut.u_core.u_issue.branch_request_o)
                profile_redirect_count = profile_redirect_count + 1;
            if (dut.u_core.u_issue.take_interrupt_i)
                profile_interrupt_count = profile_interrupt_count + 1;
            if (dut.u_core.u_issue.opcode_valid_w && !dut.u_core.u_issue.opcode_accept_r &&
                (dut.u_core.u_issue.lsu_stall_i || dut.u_core.u_issue.stall_w ||
                 dut.u_core.u_issue.div_pending_q || dut.u_core.u_issue.csr_pending_q ||
                 (dut.u_core.u_issue.issue_csr_w && !dut.u_core.u_issue.u_pipe_ctrl.pipeline_empty_o)))
                profile_issue_blocked_count = profile_issue_blocked_count + 1;

            if (workload_profile_active && !profile_marker_start && !profile_marker_end) begin
                workload_profile_cycle_count = workload_profile_cycle_count + 1;
                if (dut.u_core.u_issue.opcode_issue_r && dut.u_core.u_issue.opcode_accept_r)
                    workload_profile_issue_count = workload_profile_issue_count + 1;
                if (dut.u_core.u_issue.instruction_retired_o)
                    workload_profile_retire_count = workload_profile_retire_count + 1;
                if (dut.u_core.u_issue.lsu_stall_i)
                    workload_profile_lsu_stall_count = workload_profile_lsu_stall_count + 1;
                if (dut.u_core.u_issue.exec_hold_o)
                    workload_profile_pipe_stall_count = workload_profile_pipe_stall_count + 1;
                if (dut.u_core.u_issue.div_pending_q)
                    workload_profile_div_hold_count = workload_profile_div_hold_count + 1;
                if (dut.u_core.u_issue.csr_pending_q)
                    workload_profile_csr_hold_count = workload_profile_csr_hold_count + 1;
                if (dut.u_core.u_issue.u_pipe_ctrl.load_e1_o)
                    workload_profile_load_count = workload_profile_load_count + 1;
                if (dut.u_core.u_issue.u_pipe_ctrl.store_e1_o)
                    workload_profile_store_count = workload_profile_store_count + 1;
                if (dut.u_core.u_issue.u_pipe_ctrl.mul_e1_o)
                    workload_profile_mul_count = workload_profile_mul_count + 1;
                if (dut.u_core.u_issue.opcode_issue_r && dut.u_core.u_issue.issue_div_w)
                    workload_profile_div_count = workload_profile_div_count + 1;
                if (dut.u_core.u_issue.opcode_issue_r && dut.u_core.u_issue.issue_csr_w)
                    workload_profile_csr_count = workload_profile_csr_count + 1;
                if (dut.u_core.u_issue.branch_exec_request_i)
                    workload_profile_branch_count = workload_profile_branch_count + 1;
                if (dut.u_core.u_issue.branch_exec_is_taken_i)
                    workload_profile_branch_taken_count = workload_profile_branch_taken_count + 1;
                if (dut.u_core.u_issue.branch_request_o)
                    workload_profile_redirect_count = workload_profile_redirect_count + 1;
                if (dut.u_core.u_issue.take_interrupt_i)
                    workload_profile_interrupt_count = workload_profile_interrupt_count + 1;
                if (dut.u_core.u_issue.opcode_valid_w && !dut.u_core.u_issue.opcode_accept_r &&
                    (dut.u_core.u_issue.lsu_stall_i || dut.u_core.u_issue.stall_w ||
                     dut.u_core.u_issue.div_pending_q || dut.u_core.u_issue.csr_pending_q ||
                     (dut.u_core.u_issue.issue_csr_w && !dut.u_core.u_issue.u_pipe_ctrl.pipeline_empty_o)))
                    workload_profile_issue_blocked_count = workload_profile_issue_blocked_count + 1;
            end
        end
        if (!rst_i && irq_cycle >= 0) begin
            if (cycle_count == irq_cycle)
                intr_i[0] = 1'b1;
            else if (cycle_count == (irq_cycle + 1))
                intr_i[0] = 1'b0;
        end
        if (!rst_i && profile_marker_write) begin
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
                    $display("MODELSIM_PROFILE cycles=%0d issue=%0d retire=%0d lsu_stall=%0d pipe_stall=%0d div_hold=%0d csr_hold=%0d load=%0d store=%0d mul=%0d div=%0d csr=%0d branch=%0d branch_taken=%0d redirect=%0d interrupt=%0d issue_blocked=%0d", cycle_count, profile_issue_count, profile_retire_count, profile_lsu_stall_count, profile_pipe_stall_count, profile_div_hold_count, profile_csr_hold_count, profile_load_count, profile_store_count, profile_mul_count, profile_div_count, profile_csr_count, profile_branch_count, profile_branch_taken_count, profile_redirect_count, profile_interrupt_count, profile_issue_blocked_count);
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
