// Vendor-neutral competition peripheral block.
// The CPU reaches this block through the existing AXI-Lite external data port.
module competition_peripherals
#(
     parameter UART_CLOCK_HZ = 50000000
    ,parameter UART_BAUD     = 115200
    ,parameter UART_DIV      = (UART_CLOCK_HZ / UART_BAUD)
)
(
     input           clk_i
    ,input           rst_i

    ,input           axi_awvalid_i
    ,input  [31:0]   axi_awaddr_i
    ,input           axi_wvalid_i
    ,input  [31:0]   axi_wdata_i
    ,input  [3:0]    axi_wstrb_i
    ,input           axi_bready_i
    ,input           axi_arvalid_i
    ,input  [31:0]   axi_araddr_i
    ,input           axi_rready_i

    ,output          axi_awready_o
    ,output          axi_wready_o
    ,output          axi_bvalid_o
    ,output [1:0]    axi_bresp_o
    ,output          axi_arready_o
    ,output          axi_rvalid_o
    ,output [31:0]   axi_rdata_o
    ,output [1:0]    axi_rresp_o

    ,input  [31:0]   gpio_in_i
    ,output [31:0]   gpio_out_o
    ,output [31:0]   gpio_oe_o

    ,output          uart_tx_o
    ,output          uart_tx_busy_o
    ,output          uart_write_valid_o
    ,output [7:0]    uart_write_data_o
    ,output          timer_irq_o
);

localparam [31:0] UART_BASE  = 32'h10000000;
localparam [31:0] GPIO_BASE  = 32'h10000010;
localparam [31:0] TIMER_BASE = 32'h10000020;

localparam [31:0] UART_TX     = UART_BASE  + 32'h00;
localparam [31:0] UART_STATUS = UART_BASE  + 32'h04;
localparam [31:0] GPIO_OUT    = GPIO_BASE  + 32'h00;
localparam [31:0] GPIO_IN     = GPIO_BASE  + 32'h04;
localparam [31:0] GPIO_OE     = GPIO_BASE  + 32'h08;
localparam [31:0] TIMER_LO    = TIMER_BASE + 32'h00;
localparam [31:0] TIMER_HI    = TIMER_BASE + 32'h04;
localparam [31:0] TIMECMP_LO  = TIMER_BASE + 32'h08;
localparam [31:0] TIMECMP_HI  = TIMER_BASE + 32'h0c;
localparam [31:0] TIMER_CTRL  = TIMER_BASE + 32'h10;
localparam [31:0] TIMER_STAT  = TIMER_BASE + 32'h14;

wire write_commit_w;
wire read_accept_w;

reg        aw_pending_q;
reg        w_pending_q;
reg [31:0] awaddr_q;
reg [31:0] wdata_q;
reg [3:0]  wstrb_q;
reg        bvalid_q;
reg        rvalid_q;
reg [31:0] rdata_q;

reg [31:0] gpio_out_q;
reg [31:0] gpio_oe_q;
reg [63:0] mtime_q;
reg [63:0] mtimecmp_q;
reg        timer_enable_q;

reg [9:0]  uart_shift_q;
reg [15:0] uart_baud_count_q;
reg [3:0]  uart_bit_count_q;
reg        uart_busy_q;
reg        uart_tx_q;
reg        uart_write_valid_q;
reg [7:0]  uart_write_data_q;

wire [15:0] uart_div_w = (UART_DIV < 1) ? 16'd1 : UART_DIV[15:0];
wire timer_irq_w = timer_enable_q && (mtime_q >= mtimecmp_q);

assign axi_awready_o = !aw_pending_q && !bvalid_q;
assign axi_wready_o  = !w_pending_q  && !bvalid_q;
assign axi_bvalid_o  = bvalid_q;
assign axi_bresp_o   = 2'b00;
assign axi_arready_o = !rvalid_q && !bvalid_q && !aw_pending_q && !w_pending_q;
assign axi_rvalid_o  = rvalid_q;
assign axi_rdata_o   = rdata_q;
assign axi_rresp_o   = 2'b00;

assign write_commit_w = aw_pending_q && w_pending_q && !bvalid_q;
assign read_accept_w  = axi_arvalid_i && axi_arready_o;

assign gpio_out_o          = gpio_out_q;
assign gpio_oe_o           = gpio_oe_q;
assign uart_tx_o           = uart_tx_q;
assign uart_tx_busy_o      = uart_busy_q;
assign uart_write_valid_o  = uart_write_valid_q;
assign uart_write_data_o   = uart_write_data_q;
assign timer_irq_o         = timer_irq_w;

function [31:0] read_decode;
    input [31:0] addr;
    begin
        case (addr)
        UART_STATUS: read_decode = {30'b0, uart_busy_q, 1'b1};
        GPIO_OUT:    read_decode = gpio_out_q;
        GPIO_IN:     read_decode = gpio_in_i;
        GPIO_OE:     read_decode = gpio_oe_q;
        TIMER_LO:    read_decode = mtime_q[31:0];
        TIMER_HI:    read_decode = mtime_q[63:32];
        TIMECMP_LO:  read_decode = mtimecmp_q[31:0];
        TIMECMP_HI:  read_decode = mtimecmp_q[63:32];
        TIMER_CTRL:  read_decode = {31'b0, timer_enable_q};
        TIMER_STAT:  read_decode = {31'b0, timer_irq_w};
        default:     read_decode = 32'b0;
        endcase
    end
endfunction

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    aw_pending_q       <= 1'b0;
    w_pending_q        <= 1'b0;
    awaddr_q           <= 32'b0;
    wdata_q            <= 32'b0;
    wstrb_q            <= 4'b0;
    bvalid_q           <= 1'b0;
    rvalid_q           <= 1'b0;
    rdata_q            <= 32'b0;
    gpio_out_q         <= 32'b0;
    gpio_oe_q          <= 32'b0;
    mtime_q            <= 64'b0;
    mtimecmp_q         <= 64'hffffffffffffffff;
    timer_enable_q     <= 1'b0;
    uart_shift_q       <= 10'b1111111111;
    uart_baud_count_q  <= 16'b0;
    uart_bit_count_q   <= 4'b0;
    uart_busy_q        <= 1'b0;
    uart_tx_q          <= 1'b1;
    uart_write_valid_q <= 1'b0;
    uart_write_data_q  <= 8'b0;
end
else
begin
    uart_write_valid_q <= 1'b0;
    mtime_q            <= mtime_q + 64'd1;

    if (axi_awvalid_i && axi_awready_o)
    begin
        aw_pending_q <= 1'b1;
        awaddr_q     <= axi_awaddr_i;
    end

    if (axi_wvalid_i && axi_wready_o)
    begin
        w_pending_q <= 1'b1;
        wdata_q     <= axi_wdata_i;
        wstrb_q     <= axi_wstrb_i;
    end

    if (write_commit_w)
    begin
        aw_pending_q <= 1'b0;
        w_pending_q  <= 1'b0;
        bvalid_q     <= 1'b1;

        case (awaddr_q)
        UART_TX:
        begin
            if (wstrb_q[0])
            begin
                uart_write_valid_q <= 1'b1;
                uart_write_data_q  <= wdata_q[7:0];
                if (!uart_busy_q)
                begin
                    uart_shift_q      <= {1'b1, wdata_q[7:0], 1'b0};
                    uart_baud_count_q <= 16'b0;
                    uart_bit_count_q  <= 4'b0;
                    uart_busy_q       <= 1'b1;
                    uart_tx_q         <= 1'b0;
                end
            end
        end
        GPIO_OUT:
        begin
            if (wstrb_q[0]) gpio_out_q[7:0]   <= wdata_q[7:0];
            if (wstrb_q[1]) gpio_out_q[15:8]  <= wdata_q[15:8];
            if (wstrb_q[2]) gpio_out_q[23:16] <= wdata_q[23:16];
            if (wstrb_q[3]) gpio_out_q[31:24] <= wdata_q[31:24];
        end
        GPIO_OE:
        begin
            if (wstrb_q[0]) gpio_oe_q[7:0]   <= wdata_q[7:0];
            if (wstrb_q[1]) gpio_oe_q[15:8]  <= wdata_q[15:8];
            if (wstrb_q[2]) gpio_oe_q[23:16] <= wdata_q[23:16];
            if (wstrb_q[3]) gpio_oe_q[31:24] <= wdata_q[31:24];
        end
        TIMER_LO:
        begin
            if (wstrb_q[0]) mtime_q[7:0]   <= wdata_q[7:0];
            if (wstrb_q[1]) mtime_q[15:8]  <= wdata_q[15:8];
            if (wstrb_q[2]) mtime_q[23:16] <= wdata_q[23:16];
            if (wstrb_q[3]) mtime_q[31:24] <= wdata_q[31:24];
        end
        TIMER_HI:
        begin
            if (wstrb_q[0]) mtime_q[39:32] <= wdata_q[7:0];
            if (wstrb_q[1]) mtime_q[47:40] <= wdata_q[15:8];
            if (wstrb_q[2]) mtime_q[55:48] <= wdata_q[23:16];
            if (wstrb_q[3]) mtime_q[63:56] <= wdata_q[31:24];
        end
        TIMECMP_LO:
        begin
            if (wstrb_q[0]) mtimecmp_q[7:0]   <= wdata_q[7:0];
            if (wstrb_q[1]) mtimecmp_q[15:8]  <= wdata_q[15:8];
            if (wstrb_q[2]) mtimecmp_q[23:16] <= wdata_q[23:16];
            if (wstrb_q[3]) mtimecmp_q[31:24] <= wdata_q[31:24];
        end
        TIMECMP_HI:
        begin
            if (wstrb_q[0]) mtimecmp_q[39:32] <= wdata_q[7:0];
            if (wstrb_q[1]) mtimecmp_q[47:40] <= wdata_q[15:8];
            if (wstrb_q[2]) mtimecmp_q[55:48] <= wdata_q[23:16];
            if (wstrb_q[3]) mtimecmp_q[63:56] <= wdata_q[31:24];
        end
        TIMER_CTRL:
            if (wstrb_q[0]) timer_enable_q <= wdata_q[0];
        default:
            ;
        endcase
    end

    if (bvalid_q && axi_bready_i)
        bvalid_q <= 1'b0;

    if (read_accept_w)
    begin
        rdata_q  <= read_decode(axi_araddr_i);
        rvalid_q <= 1'b1;
    end
    else if (rvalid_q && axi_rready_i)
        rvalid_q <= 1'b0;

    if (uart_busy_q)
    begin
        if (uart_baud_count_q == uart_div_w - 1'b1)
        begin
            uart_baud_count_q <= 16'b0;
            if (uart_bit_count_q == 4'd9)
            begin
                uart_busy_q <= 1'b0;
                uart_tx_q   <= 1'b1;
            end
            else
            begin
                uart_shift_q      <= {1'b1, uart_shift_q[9:1]};
                uart_bit_count_q  <= uart_bit_count_q + 1'b1;
                uart_tx_q          <= uart_shift_q[1];
            end
        end
        else
            uart_baud_count_q <= uart_baud_count_q + 1'b1;
    end
end

endmodule
