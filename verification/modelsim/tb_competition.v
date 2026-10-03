// Competition top TCM smoke testbench.

module tb_competition;
    reg         clk_i;
    reg         rst_i;
    reg         rst_cpu_i;
    reg         ext_irq_i;
    reg [31:0]  gpio_in_i;
    wire [31:0] gpio_out_o;
    wire [31:0] gpio_oe_o;
    wire        uart_tx_o;
    wire        uart_tx_busy_o;
    wire        uart_write_valid_o;
    wire [7:0]  uart_write_data_o;

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
    integer cycle_count;
    integer pass_index;
    integer fail_index;
    integer coremark_index;
    reg pass_seen;
    reg fail_seen;
    reg coremark_mode;

    competition_top #(
        .BOOT_VECTOR(32'h00002000),
        .TCM_MEM_BASE(32'h00000000),
        .MEM_CACHE_ADDR_MIN(32'h00000000),
        .MEM_CACHE_ADDR_MAX(32'hffffffff),
        .SUPPORT_MUL_E1_BYPASS(1),
        .UART_CLOCK_HZ(115200),
        .UART_BAUD(115200)
    ) dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .rst_cpu_i(rst_cpu_i),
        .ext_irq_i(ext_irq_i),
        .gpio_in_i(gpio_in_i),
        .gpio_out_o(gpio_out_o),
        .gpio_oe_o(gpio_oe_o),
        .uart_tx_o(uart_tx_o),
        .uart_tx_busy_o(uart_tx_busy_o),
        .uart_write_valid_o(uart_write_valid_o),
        .uart_write_data_o(uart_write_data_o),
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

    function [7:0] pass_char;
        input integer offset;
        begin
            case (offset)
            0: pass_char = "C";  1: pass_char = "O";
            2: pass_char = "M";  3: pass_char = "P";
            4: pass_char = "E";  5: pass_char = "T";
            6: pass_char = "I";  7: pass_char = "T";
            8: pass_char = "I";  9: pass_char = "O";
            10: pass_char = "N"; 11: pass_char = "_";
            12: pass_char = "P"; 13: pass_char = "A";
            14: pass_char = "S"; 15: pass_char = "S";
            default: pass_char = 8'h0a;
            endcase
        end
    endfunction

    function [7:0] fail_char;
        input integer offset;
        begin
            case (offset)
            0: fail_char = "C";  1: fail_char = "O";
            2: fail_char = "M";  3: fail_char = "P";
            4: fail_char = "E";  5: fail_char = "T";
            6: fail_char = "I";  7: fail_char = "T";
            8: fail_char = "I";  9: fail_char = "O";
            10: fail_char = "N"; 11: fail_char = "_";
            12: fail_char = "F"; 13: fail_char = "A";
            14: fail_char = "I"; 15: fail_char = "L";
            default: fail_char = 8'h0a;
            endcase
        end
    endfunction

    function [7:0] coremark_char;
        input integer offset;
        begin
            case (offset)
            0: coremark_char = "C";  1: coremark_char = "O";
            2: coremark_char = "R";  3: coremark_char = "E";
            4: coremark_char = "M";  5: coremark_char = "A";
            6: coremark_char = "R";  7: coremark_char = "K";
            8: coremark_char = "_";  9: coremark_char = "M";
            10: coremark_char = "E"; 11: coremark_char = "T";
            12: coremark_char = "R"; 13: coremark_char = "I";
            14: coremark_char = "C"; 15: coremark_char = "S";
            default: coremark_char = 8'h00;
            endcase
        end
    endfunction

    always #5 clk_i = ~clk_i;

    initial begin
        clk_i = 1'b0;
        rst_i = 1'b1;
        rst_cpu_i = 1'b1;
        ext_irq_i = 1'b0;
        gpio_in_i = 32'h5a5a1234;
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
        pass_index = 0;
        fail_index = 0;
        coremark_index = 0;
        pass_seen = 1'b0;
        fail_seen = 1'b0;
        coremark_mode = $test$plusargs("COREMARK_MODE");

        for (index = 0; index < 16384; index = index + 1)
            dut.u_cpu.u_tcm.u_ram.ram[index] = 32'b0;
        $readmemh("competition.memh", dut.u_cpu.u_tcm.u_ram.ram);

        repeat (2) @(posedge clk_i);
        rst_i = 1'b0;
        rst_cpu_i = 1'b0;
        $display("COMPETITION_IMAGE_LOADED");
    end

    always @(posedge clk_i) begin
        if (!rst_i)
            cycle_count = cycle_count + 1;

        if (!rst_i && uart_write_valid_o) begin
            $write("%c", uart_write_data_o);
            if (coremark_mode && uart_write_data_o == coremark_char(coremark_index)) begin
                coremark_index = coremark_index + 1;
                if (coremark_index == 16) begin
                    pass_seen = 1'b1;
                    $display("\nCOREMARK_UART_PASS cycles=%0d", cycle_count);
                    $finish;
                end
            end
            else if (coremark_mode && uart_write_data_o == "C")
                coremark_index = 1;
            else if (coremark_mode)
                coremark_index = 0;
            else if (uart_write_data_o == pass_char(pass_index)) begin
                pass_index = pass_index + 1;
                if (pass_index == 17) begin
                    pass_seen = 1'b1;
                    if (gpio_out_o != 32'h600d0001 || gpio_oe_o != 32'hffffffff)
                        $fatal(1, "COMPETITION_FAIL: GPIO final state mismatch");
                    $display("\nCOMPETITION_TCM_PASS cycles=%0d gpio_out=%08x", cycle_count, gpio_out_o);
                    $finish;
                end
            end
            else if (uart_write_data_o == "C")
                pass_index = 1;
            else
                pass_index = 0;

            if (uart_write_data_o == fail_char(fail_index)) begin
                fail_index = fail_index + 1;
                if (fail_index == 17) begin
                    fail_seen = 1'b1;
                    $fatal(1, "COMPETITION_FAIL: software reported failure");
                end
            end
            else if (uart_write_data_o == "C")
                fail_index = 1;
            else
                fail_index = 0;
        end

        if (!rst_i && cycle_count >= 2000000)
            $fatal(1, "COMPETITION_FAIL: timeout after %0d cycles", cycle_count);
    end
endmodule
