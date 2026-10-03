// Competition integration top for the vendor-neutral TCM baseline.
// TCM remains externally loadable through axi_t_*; CPU MMIO accesses are
// terminated by competition_peripherals on the axi_i_* port.
module competition_top
#(
     parameter BOOT_VECTOR       = 32'h00002000
    ,parameter TCM_MEM_BASE      = 32'h00000000
    ,parameter MEM_CACHE_ADDR_MIN = 32'h00000000
    ,parameter MEM_CACHE_ADDR_MAX = 32'hffffffff
    ,parameter ENABLE_BRANCH_PREDICTOR = 0
    ,parameter ENABLE_BRANCH_PREDICTOR_REDIRECT = 0
    ,parameter SUPPORT_MUL_E1_BYPASS = 1
    ,parameter UART_CLOCK_HZ = 50000000
    ,parameter UART_BAUD = 115200
)
(
     input           clk_i
    ,input           rst_i
    ,input           rst_cpu_i
    ,input           ext_irq_i
    ,input  [31:0]   gpio_in_i
    ,output [31:0]   gpio_out_o
    ,output [31:0]   gpio_oe_o
    ,output          uart_tx_o
    ,output          uart_tx_busy_o
    ,output          uart_write_valid_o
    ,output [7:0]    uart_write_data_o

    ,input           axi_t_awvalid_i
    ,input  [31:0]   axi_t_awaddr_i
    ,input  [3:0]    axi_t_awid_i
    ,input  [7:0]    axi_t_awlen_i
    ,input  [1:0]    axi_t_awburst_i
    ,input           axi_t_wvalid_i
    ,input  [31:0]   axi_t_wdata_i
    ,input  [3:0]    axi_t_wstrb_i
    ,input           axi_t_wlast_i
    ,input           axi_t_bready_i
    ,input           axi_t_arvalid_i
    ,input  [31:0]   axi_t_araddr_i
    ,input  [3:0]    axi_t_arid_i
    ,input  [7:0]    axi_t_arlen_i
    ,input  [1:0]    axi_t_arburst_i
    ,input           axi_t_rready_i

    ,output          axi_t_awready_o
    ,output          axi_t_wready_o
    ,output          axi_t_bvalid_o
    ,output [1:0]    axi_t_bresp_o
    ,output [3:0]    axi_t_bid_o
    ,output          axi_t_arready_o
    ,output          axi_t_rvalid_o
    ,output [31:0]   axi_t_rdata_o
    ,output [1:0]    axi_t_rresp_o
    ,output [3:0]    axi_t_rid_o
    ,output          axi_t_rlast_o
);

wire        axi_i_awvalid_w;
wire [31:0] axi_i_awaddr_w;
wire        axi_i_wvalid_w;
wire [31:0] axi_i_wdata_w;
wire [3:0]  axi_i_wstrb_w;
wire        axi_i_bready_w;
wire        axi_i_arvalid_w;
wire [31:0] axi_i_araddr_w;
wire        axi_i_rready_w;
wire        axi_i_awready_w;
wire        axi_i_wready_w;
wire        axi_i_bvalid_w;
wire [1:0]  axi_i_bresp_w;
wire        axi_i_arready_w;
wire        axi_i_rvalid_w;
wire [31:0] axi_i_rdata_w;
wire [1:0]  axi_i_rresp_w;
wire        timer_irq_w;

riscv_tcm_top
#(
     .BOOT_VECTOR(BOOT_VECTOR)
    ,.TCM_MEM_BASE(TCM_MEM_BASE)
    ,.MEM_CACHE_ADDR_MIN(MEM_CACHE_ADDR_MIN)
    ,.MEM_CACHE_ADDR_MAX(MEM_CACHE_ADDR_MAX)
    ,.ENABLE_BRANCH_PREDICTOR(ENABLE_BRANCH_PREDICTOR)
    ,.ENABLE_BRANCH_PREDICTOR_REDIRECT(ENABLE_BRANCH_PREDICTOR_REDIRECT)
    ,.SUPPORT_MUL_E1_BYPASS(SUPPORT_MUL_E1_BYPASS)
)
u_cpu
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.rst_cpu_i(rst_cpu_i)
    ,.axi_i_awready_i(axi_i_awready_w)
    ,.axi_i_wready_i(axi_i_wready_w)
    ,.axi_i_bvalid_i(axi_i_bvalid_w)
    ,.axi_i_bresp_i(axi_i_bresp_w)
    ,.axi_i_arready_i(axi_i_arready_w)
    ,.axi_i_rvalid_i(axi_i_rvalid_w)
    ,.axi_i_rdata_i(axi_i_rdata_w)
    ,.axi_i_rresp_i(axi_i_rresp_w)
    ,.axi_t_awvalid_i(axi_t_awvalid_i)
    ,.axi_t_awaddr_i(axi_t_awaddr_i)
    ,.axi_t_awid_i(axi_t_awid_i)
    ,.axi_t_awlen_i(axi_t_awlen_i)
    ,.axi_t_awburst_i(axi_t_awburst_i)
    ,.axi_t_wvalid_i(axi_t_wvalid_i)
    ,.axi_t_wdata_i(axi_t_wdata_i)
    ,.axi_t_wstrb_i(axi_t_wstrb_i)
    ,.axi_t_wlast_i(axi_t_wlast_i)
    ,.axi_t_bready_i(axi_t_bready_i)
    ,.axi_t_arvalid_i(axi_t_arvalid_i)
    ,.axi_t_araddr_i(axi_t_araddr_i)
    ,.axi_t_arid_i(axi_t_arid_i)
    ,.axi_t_arlen_i(axi_t_arlen_i)
    ,.axi_t_arburst_i(axi_t_arburst_i)
    ,.axi_t_rready_i(axi_t_rready_i)
    ,.intr_i({31'b0, ext_irq_i})
    ,.timer_intr_i(timer_irq_w)
    ,.axi_i_awvalid_o(axi_i_awvalid_w)
    ,.axi_i_awaddr_o(axi_i_awaddr_w)
    ,.axi_i_wvalid_o(axi_i_wvalid_w)
    ,.axi_i_wdata_o(axi_i_wdata_w)
    ,.axi_i_wstrb_o(axi_i_wstrb_w)
    ,.axi_i_bready_o(axi_i_bready_w)
    ,.axi_i_arvalid_o(axi_i_arvalid_w)
    ,.axi_i_araddr_o(axi_i_araddr_w)
    ,.axi_i_rready_o(axi_i_rready_w)
    ,.axi_t_awready_o(axi_t_awready_o)
    ,.axi_t_wready_o(axi_t_wready_o)
    ,.axi_t_bvalid_o(axi_t_bvalid_o)
    ,.axi_t_bresp_o(axi_t_bresp_o)
    ,.axi_t_bid_o(axi_t_bid_o)
    ,.axi_t_arready_o(axi_t_arready_o)
    ,.axi_t_rvalid_o(axi_t_rvalid_o)
    ,.axi_t_rdata_o(axi_t_rdata_o)
    ,.axi_t_rresp_o(axi_t_rresp_o)
    ,.axi_t_rid_o(axi_t_rid_o)
    ,.axi_t_rlast_o(axi_t_rlast_o)
);

competition_peripherals
#(
     .UART_CLOCK_HZ(UART_CLOCK_HZ)
    ,.UART_BAUD(UART_BAUD)
)
u_peripherals
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.axi_awvalid_i(axi_i_awvalid_w)
    ,.axi_awaddr_i(axi_i_awaddr_w)
    ,.axi_wvalid_i(axi_i_wvalid_w)
    ,.axi_wdata_i(axi_i_wdata_w)
    ,.axi_wstrb_i(axi_i_wstrb_w)
    ,.axi_bready_i(axi_i_bready_w)
    ,.axi_arvalid_i(axi_i_arvalid_w)
    ,.axi_araddr_i(axi_i_araddr_w)
    ,.axi_rready_i(axi_i_rready_w)
    ,.axi_awready_o(axi_i_awready_w)
    ,.axi_wready_o(axi_i_wready_w)
    ,.axi_bvalid_o(axi_i_bvalid_w)
    ,.axi_bresp_o(axi_i_bresp_w)
    ,.axi_arready_o(axi_i_arready_w)
    ,.axi_rvalid_o(axi_i_rvalid_w)
    ,.axi_rdata_o(axi_i_rdata_w)
    ,.axi_rresp_o(axi_i_rresp_w)
    ,.gpio_in_i(gpio_in_i)
    ,.gpio_out_o(gpio_out_o)
    ,.gpio_oe_o(gpio_oe_o)
    ,.uart_tx_o(uart_tx_o)
    ,.uart_tx_busy_o(uart_tx_busy_o)
    ,.uart_write_valid_o(uart_write_valid_o)
    ,.uart_write_data_o(uart_write_data_o)
    ,.timer_irq_o(timer_irq_w)
);

endmodule
