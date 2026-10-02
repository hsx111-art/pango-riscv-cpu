//-----------------------------------------------------------------
// Small, optional dynamic branch predictor prototype.
//
// The predictor is deliberately conservative: one unresolved branch is
// tracked at a time, JALR is not predicted, and control-flow redirection is
// disabled by default because the current pipeline has no squash mechanism
// for wrong-path instructions issued before execute-stage resolution.
//-----------------------------------------------------------------
module riscv_branch_predictor
#(
     parameter ENABLE        = 0
    ,parameter ENTRIES       = 16
    ,parameter INDEX_BITS    = 4
    ,parameter ENABLE_REDIRECT = 0
)
(
     input           clk_i
    ,input           rst_i
    ,input           fetch_valid_i
    ,input           fetch_accept_i
    ,input  [31:0]   fetch_pc_i
    ,input  [31:0]   fetch_instr_i
    ,input           fetch_fault_i
    ,input  [ 1:0]   fetch_priv_i
    ,input           resolve_valid_i
    ,input           resolve_taken_i
    ,input  [31:0]   resolve_source_i
    ,input  [31:0]   resolve_pc_i
    ,input           branch_d_valid_i
    ,input  [31:0]   branch_d_source_i
    ,input  [31:0]   branch_d_pc_i
    ,output          predict_valid_o
    ,output          predict_taken_o
    ,output [31:0]   predict_target_o
    ,output          suppress_redirect_o
    ,output          recover_valid_o
    ,output [31:0]   recover_pc_o
    ,output [ 1:0]   recover_priv_o
    ,output          predictor_event_o
    ,output          predictor_taken_event_o
    ,output          predictor_correct_o
    ,output          predictor_mispredict_o
    ,output          predictor_recover_o
);

`include "riscv_defs.v"

localparam TAG_WIDTH = 32 - INDEX_BITS - 2;

reg                    btb_valid_q  [0:ENTRIES-1];
reg [TAG_WIDTH-1:0]    btb_tag_q    [0:ENTRIES-1];
reg [31:0]             btb_target_q [0:ENTRIES-1];
reg [1:0]              bht_q        [0:ENTRIES-1];

reg                    pending_q;
reg [31:0]              pending_source_q;
reg [31:0]              pending_target_q;
reg [1:0]               pending_priv_q;
reg                    pending_taken_q;

wire [INDEX_BITS-1:0] fetch_index_w = fetch_pc_i[INDEX_BITS+1:2];
wire [INDEX_BITS-1:0] resolve_index_w = resolve_source_i[INDEX_BITS+1:2];
wire [TAG_WIDTH-1:0] fetch_tag_w = fetch_pc_i[31:INDEX_BITS+2];

wire fetch_jal_w = (fetch_instr_i & `INST_JAL_MASK) == `INST_JAL;
wire fetch_jalr_w = (fetch_instr_i & `INST_JALR_MASK) == `INST_JALR;
wire fetch_cond_w = ((fetch_instr_i & `INST_BEQ_MASK) == `INST_BEQ)   ||
                    ((fetch_instr_i & `INST_BNE_MASK) == `INST_BNE)   ||
                    ((fetch_instr_i & `INST_BLT_MASK) == `INST_BLT)   ||
                    ((fetch_instr_i & `INST_BGE_MASK) == `INST_BGE)   ||
                    ((fetch_instr_i & `INST_BLTU_MASK) == `INST_BLTU) ||
                    ((fetch_instr_i & `INST_BGEU_MASK) == `INST_BGEU);
// Keep unconditional JAL on the already-validated direct redirect path in
// this first prototype. Conditional branches exercise the BHT/BTB state
// without changing call/return fetch timing yet.
wire fetch_eligible_w = fetch_cond_w;
wire btb_hit_w = btb_valid_q[fetch_index_w] &&
                  (btb_tag_q[fetch_index_w] == fetch_tag_w);

wire [31:0] fetch_bimm_w = {{19{fetch_instr_i[31]}}, fetch_instr_i[31],
                             fetch_instr_i[7], fetch_instr_i[30:25],
                             fetch_instr_i[11:8], 1'b0};
wire [31:0] fetch_jimm_w = {{12{fetch_instr_i[31]}}, fetch_instr_i[19:12],
                             fetch_instr_i[20], fetch_instr_i[30:25],
                             fetch_instr_i[24:21], 1'b0};
wire [31:0] fetch_static_target_w = fetch_pc_i +
                                    (fetch_jal_w ? fetch_jimm_w : fetch_bimm_w);
wire fetch_event_w = (ENABLE != 0) && fetch_valid_i && fetch_accept_i &&
                     !fetch_fault_i && fetch_eligible_w && !pending_q;
wire redirect_enabled_w = (ENABLE != 0) && (ENABLE_REDIRECT != 0);
wire fetch_predict_taken_w = fetch_jal_w ||
                             (fetch_cond_w && bht_q[fetch_index_w][1]);
wire [31:0] fetch_predict_target_w = btb_hit_w ?
                                     btb_target_q[fetch_index_w] :
                                     fetch_static_target_w;

assign predict_valid_o          = fetch_event_w;
assign predict_taken_o          = redirect_enabled_w && fetch_event_w &&
                                   fetch_predict_taken_w;
assign predict_target_o         = fetch_predict_target_w;
assign predictor_event_o        = fetch_event_w;
assign predictor_taken_event_o  = fetch_event_w && fetch_predict_taken_w;

// A direct taken redirect is redundant when the same branch was predicted
// taken and the execute target agrees with that prediction.
assign suppress_redirect_o = redirect_enabled_w && branch_d_valid_i && pending_q &&
                             pending_taken_q &&
                             (pending_source_q == branch_d_source_i) &&
                             (pending_target_q == branch_d_pc_i);

// A predicted-taken branch that resolves not-taken must recover to its
// sequential PC. Predicted-not-taken/taken recovery is handled by the
// existing branch_d redirect path.
assign recover_valid_o = redirect_enabled_w && resolve_valid_i && pending_q &&
                         pending_taken_q &&
                         (pending_source_q == resolve_source_i) &&
                         !resolve_taken_i;
assign recover_pc_o    = resolve_pc_i;
assign recover_priv_o  = pending_priv_q;
assign predictor_recover_o = recover_valid_o;
assign predictor_correct_o = (ENABLE != 0) && resolve_valid_i && pending_q &&
                             (pending_source_q == resolve_source_i) &&
                             (pending_taken_q == resolve_taken_i);
assign predictor_mispredict_o = (ENABLE != 0) && resolve_valid_i && pending_q &&
                                (pending_source_q == resolve_source_i) &&
                                (pending_taken_q != resolve_taken_i);

integer i;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    pending_q        <= 1'b0;
    pending_source_q <= 32'b0;
    pending_target_q <= 32'b0;
    pending_priv_q   <= `PRIV_MACHINE;
    pending_taken_q  <= 1'b0;
    for (i = 0; i < ENTRIES; i = i + 1)
    begin
        btb_valid_q[i]  <= 1'b0;
        btb_tag_q[i]    <= {TAG_WIDTH{1'b0}};
        btb_target_q[i] <= 32'b0;
        bht_q[i]        <= 2'b01;
    end
end
else if (ENABLE != 0)
begin
    if (resolve_valid_i)
    begin
        btb_valid_q[resolve_index_w]  <= 1'b1;
        btb_tag_q[resolve_index_w]    <= resolve_source_i[31:INDEX_BITS+2];
        btb_target_q[resolve_index_w] <= resolve_pc_i;

        if (resolve_taken_i)
        begin
            if (bht_q[resolve_index_w] != 2'b11)
                bht_q[resolve_index_w] <= bht_q[resolve_index_w] + 2'b01;
        end
        else if (bht_q[resolve_index_w] != 2'b00)
            bht_q[resolve_index_w] <= bht_q[resolve_index_w] - 2'b01;
    end

    if (pending_q && resolve_valid_i &&
        (pending_source_q == resolve_source_i))
        pending_q <= 1'b0;

    if (fetch_event_w)
    begin
        pending_q        <= 1'b1;
        pending_source_q <= fetch_pc_i;
        pending_target_q <= fetch_predict_target_w;
        pending_priv_q   <= fetch_priv_i;
        pending_taken_q  <= fetch_predict_taken_w;
    end
end

`ifdef verilator
function [0:0] profile_predictor_event; /*verilator public*/
begin
    profile_predictor_event = predictor_event_o;
end
endfunction
function [0:0] profile_predictor_taken; /*verilator public*/
begin
    profile_predictor_taken = predictor_taken_event_o;
end
endfunction
function [0:0] profile_predictor_correct; /*verilator public*/
begin
    profile_predictor_correct = predictor_correct_o;
end
endfunction
function [0:0] profile_predictor_mispredict; /*verilator public*/
begin
    profile_predictor_mispredict = predictor_mispredict_o;
end
endfunction
function [0:0] profile_predictor_recover; /*verilator public*/
begin
    profile_predictor_recover = predictor_recover_o;
end
endfunction
`endif

endmodule
