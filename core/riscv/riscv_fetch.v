//-----------------------------------------------------------------
//                         RISC-V Core
//                            V1.0.1
//                     Ultra-Embedded.com
//                     Copyright 2014-2019
//
//                   admin@ultra-embedded.com
//
//                       License: BSD
//-----------------------------------------------------------------
//
// Copyright (c) 2014-2019, Ultra-Embedded.com
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions 
// are met:
//   - Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer 
//     in the documentation and/or other materials provided with the 
//     distribution.
//   - Neither the name of the author nor the names of its contributors 
//     may be used to endorse or promote products derived from this 
//     software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE 
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF 
// SUCH DAMAGE.
//-----------------------------------------------------------------

module riscv_fetch
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter SUPPORT_MMU      = 1
    ,parameter ENABLE_BRANCH_PREDICTOR = 0
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           fetch_accept_i
    ,input           icache_accept_i
    ,input           icache_valid_i
    ,input           icache_error_i
    ,input  [ 31:0]  icache_inst_i
    ,input           icache_page_fault_i
    ,input           fetch_invalidate_i
    ,input           branch_request_i
    ,input  [ 31:0]  branch_pc_i
    ,input  [  1:0]  branch_priv_i
    ,input           branch_d_request_i
    ,input  [ 31:0]  branch_d_source_i
    ,input           branch_exec_request_i
    ,input           branch_exec_is_taken_i
    ,input  [ 31:0]  branch_exec_source_i
    ,input  [ 31:0]  branch_exec_pc_i

    // Outputs
    ,output          fetch_valid_o
    ,output [ 31:0]  fetch_instr_o
    ,output [ 31:0]  fetch_pc_o
    ,output          fetch_fault_fetch_o
    ,output          fetch_fault_page_o
    ,output          icache_rd_o
    ,output          icache_flush_o
    ,output          icache_invalidate_o
    ,output [ 31:0]  icache_pc_o
    ,output [  1:0]  icache_priv_o
    ,output          squash_decode_o
);



//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "riscv_defs.v"

//-------------------------------------------------------------
// Registers / Wires
//-------------------------------------------------------------
reg         active_q;

wire        icache_busy_w;
wire        stall_w       = !fetch_accept_i || icache_busy_w || !icache_accept_i;

wire        predictor_valid_w;
wire        predictor_taken_w;
wire [31:0] predictor_target_w;
wire        predictor_suppress_w;
wire        predictor_recover_w;
wire [31:0] predictor_recover_pc_w;
wire [ 1:0] predictor_recover_priv_w;
wire        predictor_event_w;
wire        predictor_taken_event_w;
wire        predictor_correct_w;
wire        predictor_mispredict_w;
wire        predictor_recover_event_w;

wire        branch_request_effective_w = predictor_recover_w ||
                                         (branch_request_i && !predictor_suppress_w);
wire [31:0] branch_pc_effective_w = predictor_recover_w ?
                                    predictor_recover_pc_w : branch_pc_i;
wire [1:0]  branch_priv_effective_w = predictor_recover_w ?
                                      predictor_recover_priv_w : branch_priv_i;

//-------------------------------------------------------------
// Buffered branch
//-------------------------------------------------------------
reg         branch_q;
reg [31:0]  branch_pc_q;
reg [1:0]   branch_priv_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    branch_q       <= 1'b0;
    branch_pc_q    <= 32'b0;
    branch_priv_q  <= `PRIV_MACHINE;
end
else if (branch_request_effective_w)
begin
    if (stall_w)
    begin
        branch_q       <= 1'b1;
        branch_pc_q    <= branch_pc_effective_w;
        branch_priv_q  <= branch_priv_effective_w;
    end
    else
    begin
        branch_q       <= 1'b0;
        branch_pc_q    <= 32'b0;
        branch_priv_q  <= `PRIV_MACHINE;
    end
end
else if (icache_rd_o && icache_accept_i)
begin
    branch_q       <= 1'b0;
    branch_pc_q    <= 32'b0;
end

wire        branch_w      = branch_q;
wire [31:0] branch_pc_w   = branch_pc_q;
wire [1:0]  branch_priv_w = branch_priv_q;
wire        branch_direct_w = branch_request_effective_w && !stall_w;
wire        branch_pending_w = branch_w && !stall_w;
wire        branch_redirect_w = branch_direct_w || branch_pending_w;
wire [31:0] branch_redirect_pc_w = branch_direct_w ?
                                   branch_pc_effective_w : branch_pc_w;
wire [1:0]  branch_redirect_priv_w = branch_direct_w ?
                                     branch_priv_effective_w : branch_priv_w;

assign squash_decode_o    = branch_request_effective_w;

//-------------------------------------------------------------
// Active flag
//-------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    active_q    <= 1'b0;
else if (branch_redirect_w)
    active_q    <= 1'b1;

//-------------------------------------------------------------
// Stall flag
//-------------------------------------------------------------
reg stall_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    stall_q    <= 1'b0;
else
    stall_q    <= stall_w;

//-------------------------------------------------------------
// Request tracking
//-------------------------------------------------------------
reg icache_fetch_q;
reg icache_invalidate_q;

// ICACHE fetch tracking
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    icache_fetch_q <= 1'b0;
else if (icache_rd_o && icache_accept_i)
    icache_fetch_q <= 1'b1;
else if (icache_valid_i)
    icache_fetch_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    icache_invalidate_q <= 1'b0;
else if (icache_invalidate_o && !icache_accept_i)
    icache_invalidate_q <= 1'b1;
else
    icache_invalidate_q <= 1'b0;

//-------------------------------------------------------------
// PC
//-------------------------------------------------------------
reg [31:0]  pc_f_q;
reg [31:0]  pc_d_q;

wire [31:0] icache_pc_w;
wire [1:0]  icache_priv_w;
wire        fetch_resp_drop_w;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    pc_f_q  <= 32'b0;
// Branch request
else if (branch_redirect_w)
    pc_f_q  <= branch_redirect_pc_w;
// NPC
else if (!stall_w)
    pc_f_q  <= (predictor_valid_w && predictor_taken_w) ?
               predictor_target_w : {icache_pc_w[31:2],2'b0} + 32'd4;

reg [1:0] priv_f_q;
reg       branch_d_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    priv_f_q  <= `PRIV_MACHINE;
// Branch request
else if (branch_redirect_w)
    priv_f_q  <= branch_redirect_priv_w;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    branch_d_q  <= 1'b0;
// Branch request
else if (branch_redirect_w)
    branch_d_q  <= 1'b1;
// NPC
else if (!stall_w)
    branch_d_q  <= 1'b0;

assign icache_pc_w       = pc_f_q;
assign icache_priv_w     = priv_f_q;
// The registered branch_d_q pulse preserves the existing response discard
// window without feeding the combinational branch request back into decode.
assign fetch_resp_drop_w = branch_w | branch_d_q;

// Last fetch address
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    pc_d_q <= 32'b0;
else if (icache_rd_o && icache_accept_i)
    pc_d_q <= icache_pc_w;

//-------------------------------------------------------------
// Outputs
//-------------------------------------------------------------
assign icache_rd_o         = active_q & fetch_accept_i & !icache_busy_w;
assign icache_pc_o         = {icache_pc_w[31:2],2'b0};
assign icache_priv_o       = icache_priv_w;
assign icache_flush_o      = fetch_invalidate_i | icache_invalidate_q;
assign icache_invalidate_o = 1'b0;

assign icache_busy_w       =  icache_fetch_q && !icache_valid_i;

//-------------------------------------------------------------
// Response Buffer
//-------------------------------------------------------------
reg [65:0]  skid_buffer_q;
reg         skid_valid_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    skid_buffer_q  <= 66'b0;
    skid_valid_q   <= 1'b0;
end 
// Instruction output back-pressured - hold in skid buffer
else if (fetch_valid_o && !fetch_accept_i)
begin
    skid_valid_q  <= 1'b1;
    skid_buffer_q <= {fetch_fault_page_o, fetch_fault_fetch_o, fetch_pc_o, fetch_instr_o};
end
else
begin
    skid_valid_q  <= 1'b0;
    skid_buffer_q <= 66'b0;
end

assign fetch_valid_o       = (icache_valid_i || skid_valid_q) & !fetch_resp_drop_w;
assign fetch_pc_o          = skid_valid_q ? skid_buffer_q[63:32] : {pc_d_q[31:2],2'b0};
assign fetch_instr_o       = skid_valid_q ? skid_buffer_q[31:0]  : icache_inst_i;

// Faults
assign fetch_fault_fetch_o = skid_valid_q ? skid_buffer_q[64] : icache_error_i;
assign fetch_fault_page_o  = skid_valid_q ? skid_buffer_q[65] : icache_page_fault_i;

// The predictor observes the instruction actually accepted by decode. It is
// therefore also correct when a response spent time in the skid buffer.
riscv_branch_predictor
#(
     .ENABLE(ENABLE_BRANCH_PREDICTOR)
)
u_predictor
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.fetch_valid_i(fetch_valid_o)
    ,.fetch_accept_i(fetch_accept_i)
    ,.fetch_pc_i(fetch_pc_o)
    ,.fetch_instr_i(fetch_instr_o)
    ,.fetch_fault_i(fetch_fault_fetch_o | fetch_fault_page_o)
    ,.fetch_priv_i(icache_priv_w)
    ,.resolve_valid_i(branch_exec_request_i)
    ,.resolve_taken_i(branch_exec_is_taken_i)
    ,.resolve_source_i(branch_exec_source_i)
    ,.resolve_pc_i(branch_exec_pc_i)
    ,.branch_d_valid_i(branch_d_request_i)
    ,.branch_d_source_i(branch_d_source_i)
    ,.branch_d_pc_i(branch_pc_i)
    ,.predict_valid_o(predictor_valid_w)
    ,.predict_taken_o(predictor_taken_w)
    ,.predict_target_o(predictor_target_w)
    ,.suppress_redirect_o(predictor_suppress_w)
    ,.recover_valid_o(predictor_recover_w)
    ,.recover_pc_o(predictor_recover_pc_w)
    ,.recover_priv_o(predictor_recover_priv_w)
    ,.predictor_event_o(predictor_event_w)
    ,.predictor_taken_event_o(predictor_taken_event_w)
    ,.predictor_correct_o(predictor_correct_w)
    ,.predictor_mispredict_o(predictor_mispredict_w)
    ,.predictor_recover_o(predictor_recover_event_w)
);

`ifdef verilator
function [0:0] profile_predictor_event; /*verilator public*/
begin
    profile_predictor_event = predictor_event_w;
end
endfunction
function [0:0] profile_predictor_taken; /*verilator public*/
begin
    profile_predictor_taken = predictor_taken_event_w;
end
endfunction
function [0:0] profile_predictor_correct; /*verilator public*/
begin
    profile_predictor_correct = predictor_correct_w;
end
endfunction
function [0:0] profile_predictor_mispredict; /*verilator public*/
begin
    profile_predictor_mispredict = predictor_mispredict_w;
end
endfunction
function [0:0] profile_predictor_recover; /*verilator public*/
begin
    profile_predictor_recover = predictor_recover_event_w;
end
endfunction
`endif



endmodule
