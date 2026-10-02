#include "testbench_vbase.h"

#include "riscv_main.h"
#include "riscv.h"
#include "elf_load.h"

#include <unistd.h>
#include <stdio.h>

#include "cosim_api.h"

#include "riscv_tcm_top_rtl.h"
#include "Vriscv_tcm_top.h"
#include "Vriscv_tcm_top__Syms.h"

#include "verilated.h"
#include "verilated_vcd_sc.h"

//-----------------------------------------------------------------
// Module
//-----------------------------------------------------------------
class testbench: public testbench_vbase, public cosim_cpu_api, public cosim_mem_api
{
public:
    //-----------------------------------------------------------------
    // Instances / Members
    //-----------------------------------------------------------------      
    riscv_tcm_top_rtl           *m_dut;

    int                          m_argc;
    char**                       m_argv;
    int                          m_irq_cycle;
    unsigned                     m_step_count;
    bool                         m_metrics_reported;
    unsigned long long           m_profile_issue;
    unsigned long long           m_profile_retire;
    unsigned long long           m_profile_lsu_stall;
    unsigned long long           m_profile_pipe_stall;
    unsigned long long           m_profile_div_hold;
    unsigned long long           m_profile_csr_hold;
    unsigned long long           m_profile_load_issue;
    unsigned long long           m_profile_store_issue;
    unsigned long long           m_profile_mul_issue;
    unsigned long long           m_profile_div_issue;
    unsigned long long           m_profile_csr_issue;
    unsigned long long           m_profile_branch;
    unsigned long long           m_profile_branch_taken;
    unsigned long long           m_profile_predictor_event;
    unsigned long long           m_profile_predictor_taken;
    unsigned long long           m_profile_predictor_correct;
    unsigned long long           m_profile_predictor_mispredict;
    unsigned long long           m_profile_predictor_recover;
    unsigned long long           m_profile_redirect;
    unsigned long long           m_profile_interrupt;
    unsigned long long           m_profile_issue_blocked;
    bool                         m_workload_profile_active;
    bool                         m_workload_profile_start_seen;
    bool                         m_workload_profile_end_seen;
    unsigned                     m_workload_profile_start_step;
    bool                         m_predictor_debug;
    unsigned                     m_predictor_debug_events;
    unsigned                     m_workload_profile_cycle_count;
    unsigned long long           m_workload_profile_issue;
    unsigned long long           m_workload_profile_retire;
    unsigned long long           m_workload_profile_lsu_stall;
    unsigned long long           m_workload_profile_pipe_stall;
    unsigned long long           m_workload_profile_div_hold;
    unsigned long long           m_workload_profile_csr_hold;
    unsigned long long           m_workload_profile_load_issue;
    unsigned long long           m_workload_profile_store_issue;
    unsigned long long           m_workload_profile_mul_issue;
    unsigned long long           m_workload_profile_div_issue;
    unsigned long long           m_workload_profile_csr_issue;
    unsigned long long           m_workload_profile_branch;
    unsigned long long           m_workload_profile_branch_taken;
    unsigned long long           m_workload_profile_predictor_event;
    unsigned long long           m_workload_profile_predictor_taken;
    unsigned long long           m_workload_profile_predictor_correct;
    unsigned long long           m_workload_profile_predictor_mispredict;
    unsigned long long           m_workload_profile_predictor_recover;
    unsigned long long           m_workload_profile_redirect;
    unsigned long long           m_workload_profile_interrupt;
    unsigned long long           m_workload_profile_issue_blocked;
    //-----------------------------------------------------------------
    // Signals
    //-----------------------------------------------------------------    
    sc_signal <bool>            rst_cpu_in;

    sc_signal <axi4_master>      axi_t_in;
    sc_signal <axi4_slave>       axi_t_out;

    sc_signal <axi4_lite_master> axi_i_out;
    sc_signal <axi4_lite_slave>  axi_i_in;

    sc_signal < sc_uint <32> >   intr_in;


    //-----------------------------------------------------------------
    // process: Main loop for CPU execution
    //-----------------------------------------------------------------
    void process(void) 
    {
        cosim::instance()->attach_cpu("rtl", this);
        cosim::instance()->attach_mem("rtl", this, 0, 0xFFFFFFFF);
        wait();
        exit(riscv_main(cosim::instance(), m_argc, m_argv));
    }

    void set_argcv(int argc, char* argv[]) { m_argc = argc; m_argv = argv; }

    void report_metrics(void)
    {
        if (m_metrics_reported)
            return;

        m_metrics_reported = true;
        unsigned mcycle = m_dut->m_rtl->v->u_core->u_csr->u_csrfile->get_mcycle();
        unsigned minstret = m_dut->m_rtl->v->u_core->u_csr->u_csrfile->get_minstret();
        double cpi = minstret ? (double)mcycle / (double)minstret : 0.0;
        printf("WSL_METRICS steps=%u retired=%u mcycle=%08x minstret=%08x cpi=%.6f\n",
               m_step_count, minstret, mcycle, minstret, cpi);
        printf("WSL_PROFILE cycles=%u issue=%llu retire=%llu lsu_stall=%llu pipe_stall=%llu div_hold=%llu csr_hold=%llu load=%llu store=%llu mul=%llu div=%llu csr=%llu branch=%llu branch_taken=%llu predictor_event=%llu predictor_taken=%llu predictor_correct=%llu predictor_mispredict=%llu predictor_recover=%llu redirect=%llu interrupt=%llu issue_blocked=%llu\n",
               m_step_count,
               m_profile_issue,
               m_profile_retire,
               m_profile_lsu_stall,
               m_profile_pipe_stall,
               m_profile_div_hold,
               m_profile_csr_hold,
               m_profile_load_issue,
               m_profile_store_issue,
               m_profile_mul_issue,
               m_profile_div_issue,
               m_profile_csr_issue,
               m_profile_branch,
               m_profile_branch_taken,
               m_profile_predictor_event,
               m_profile_predictor_taken,
               m_profile_predictor_correct,
               m_profile_predictor_mispredict,
               m_profile_predictor_recover,
               m_profile_redirect,
               m_profile_interrupt,
               m_profile_issue_blocked);
        if (m_workload_profile_start_seen && m_workload_profile_end_seen)
            printf("WSL_WORKLOAD_PROFILE cycles=%u issue=%llu retire=%llu lsu_stall=%llu pipe_stall=%llu div_hold=%llu csr_hold=%llu load=%llu store=%llu mul=%llu div=%llu csr=%llu branch=%llu branch_taken=%llu predictor_event=%llu predictor_taken=%llu predictor_correct=%llu predictor_mispredict=%llu predictor_recover=%llu redirect=%llu interrupt=%llu issue_blocked=%llu\n",
                   m_workload_profile_cycle_count,
                   m_workload_profile_issue,
                   m_workload_profile_retire,
                   m_workload_profile_lsu_stall,
                   m_workload_profile_pipe_stall,
                   m_workload_profile_div_hold,
                   m_workload_profile_csr_hold,
                   m_workload_profile_load_issue,
                   m_workload_profile_store_issue,
                   m_workload_profile_mul_issue,
                   m_workload_profile_div_issue,
                   m_workload_profile_csr_issue,
                   m_workload_profile_branch,
                   m_workload_profile_branch_taken,
                   m_workload_profile_predictor_event,
                   m_workload_profile_predictor_taken,
                   m_workload_profile_predictor_correct,
                   m_workload_profile_predictor_mispredict,
                   m_workload_profile_predictor_recover,
                   m_workload_profile_redirect,
                   m_workload_profile_interrupt,
                   m_workload_profile_issue_blocked);
        else
            printf("WSL_WORKLOAD_PROFILE_MISSING start=%d end=%d\n",
                   m_workload_profile_start_seen ? 1 : 0,
                   m_workload_profile_end_seen ? 1 : 0);
    }

    void sample_profile(bool count_workload)
    {
        auto issue = m_dut->m_rtl->v->u_core->u_issue;
        auto predictor = m_dut->m_rtl->v->u_core->u_fetch->u_predictor;
        m_profile_issue          += issue->profile_issue();
        m_profile_retire        += issue->profile_retire();
        m_profile_lsu_stall     += issue->profile_lsu_stall();
        m_profile_pipe_stall    += issue->profile_pipe_stall();
        m_profile_div_hold      += issue->profile_div_hold();
        m_profile_csr_hold      += issue->profile_csr_hold();
        m_profile_load_issue    += issue->profile_load_issue();
        m_profile_store_issue   += issue->profile_store_issue();
        m_profile_mul_issue     += issue->profile_mul_issue();
        m_profile_div_issue     += issue->profile_div_issue();
        m_profile_csr_issue     += issue->profile_csr_issue();
        m_profile_branch        += issue->profile_branch();
        m_profile_branch_taken += issue->profile_branch_taken();
        m_profile_predictor_event      += predictor->profile_predictor_event();
        m_profile_predictor_taken      += predictor->profile_predictor_taken();
        m_profile_predictor_correct    += predictor->profile_predictor_correct();
        m_profile_predictor_mispredict += predictor->profile_predictor_mispredict();
        m_profile_predictor_recover    += predictor->profile_predictor_recover();
        m_profile_redirect      += issue->profile_redirect();
        m_profile_interrupt     += issue->profile_interrupt();
        m_profile_issue_blocked += issue->profile_issue_blocked();

        const bool predictor_debug_event = predictor->profile_predictor_mispredict() ||
                                           predictor->profile_predictor_recover() ||
                                           predictor->__PVT__branch_d_valid_i;
        if (m_predictor_debug && predictor_debug_event &&
            m_predictor_debug_events < 200)
        {
            printf("PREDICTOR_DEBUG step=%u fetch_valid=%d fetch_pc=%08x instr=%08x "
                   "pred_valid=%d pred_taken=%d pred_target=%08x pending=%d "
                   "pending_source=%08x pending_target=%08x pending_taken=%d "
                   "branch_d=%d branch_d_source=%08x branch_d_target=%08x "
                   "resolve=%d resolve_source=%08x resolve_taken=%d resolve_pc=%08x "
                   "correct=%d mispredict=%d recover=%d suppress=%d\n",
                   m_step_count,
                   predictor->__PVT__fetch_valid_i,
                   predictor->__PVT__fetch_pc_i,
                   predictor->__PVT__fetch_instr_i,
                   predictor->__PVT__predict_valid_o,
                   predictor->__PVT__predict_taken_o,
                   predictor->__PVT__predict_target_o,
                   predictor->__PVT__pending_q,
                   predictor->__PVT__pending_source_q,
                   predictor->__PVT__pending_target_q,
                   predictor->__PVT__pending_taken_q,
                   predictor->__PVT__branch_d_valid_i,
                   predictor->__PVT__branch_d_source_i,
                   predictor->__PVT__branch_d_pc_i,
                   predictor->__PVT__resolve_valid_i,
                   predictor->__PVT__resolve_source_i,
                   predictor->__PVT__resolve_taken_i,
                   predictor->__PVT__resolve_pc_i,
                   predictor->__PVT__predictor_correct_o,
                   predictor->__PVT__predictor_mispredict_o,
                   predictor->__PVT__recover_valid_o,
                   predictor->__PVT__suppress_redirect_o);
            m_predictor_debug_events++;
        }
        if (count_workload)
        {
            m_workload_profile_issue          += issue->profile_issue();
            m_workload_profile_retire         += issue->profile_retire();
            m_workload_profile_lsu_stall      += issue->profile_lsu_stall();
            m_workload_profile_pipe_stall     += issue->profile_pipe_stall();
            m_workload_profile_div_hold       += issue->profile_div_hold();
            m_workload_profile_csr_hold       += issue->profile_csr_hold();
            m_workload_profile_load_issue     += issue->profile_load_issue();
            m_workload_profile_store_issue    += issue->profile_store_issue();
            m_workload_profile_mul_issue      += issue->profile_mul_issue();
            m_workload_profile_div_issue      += issue->profile_div_issue();
            m_workload_profile_csr_issue      += issue->profile_csr_issue();
            m_workload_profile_branch         += issue->profile_branch();
            m_workload_profile_branch_taken  += issue->profile_branch_taken();
            m_workload_profile_predictor_event      += predictor->profile_predictor_event();
            m_workload_profile_predictor_taken      += predictor->profile_predictor_taken();
            m_workload_profile_predictor_correct    += predictor->profile_predictor_correct();
            m_workload_profile_predictor_mispredict += predictor->profile_predictor_mispredict();
            m_workload_profile_predictor_recover    += predictor->profile_predictor_recover();
            m_workload_profile_redirect       += issue->profile_redirect();
            m_workload_profile_interrupt      += issue->profile_interrupt();
            m_workload_profile_issue_blocked += issue->profile_issue_blocked();
        }
    }

    void reset_workload_profile(void)
    {
        m_workload_profile_cycle_count = 0;
        m_workload_profile_issue = 0;
        m_workload_profile_retire = 0;
        m_workload_profile_lsu_stall = 0;
        m_workload_profile_pipe_stall = 0;
        m_workload_profile_div_hold = 0;
        m_workload_profile_csr_hold = 0;
        m_workload_profile_load_issue = 0;
        m_workload_profile_store_issue = 0;
        m_workload_profile_mul_issue = 0;
        m_workload_profile_div_issue = 0;
        m_workload_profile_csr_issue = 0;
        m_workload_profile_branch = 0;
        m_workload_profile_branch_taken = 0;
        m_workload_profile_predictor_event = 0;
        m_workload_profile_predictor_taken = 0;
        m_workload_profile_predictor_correct = 0;
        m_workload_profile_predictor_mispredict = 0;
        m_workload_profile_predictor_recover = 0;
        m_workload_profile_redirect = 0;
        m_workload_profile_interrupt = 0;
        m_workload_profile_issue_blocked = 0;
    }

    //-----------------------------------------------------------------
    // Construction
    //-----------------------------------------------------------------
    SC_HAS_PROCESS(testbench);
    testbench(sc_module_name name): testbench_vbase(name)
    {
        m_irq_cycle  = -1;
        m_step_count = 0;
        m_metrics_reported = false;
        m_profile_issue = 0;
        m_profile_retire = 0;
        m_profile_lsu_stall = 0;
        m_profile_pipe_stall = 0;
        m_profile_div_hold = 0;
        m_profile_csr_hold = 0;
        m_profile_load_issue = 0;
        m_profile_store_issue = 0;
        m_profile_mul_issue = 0;
        m_profile_div_issue = 0;
        m_profile_csr_issue = 0;
        m_profile_branch = 0;
        m_profile_branch_taken = 0;
        m_profile_predictor_event = 0;
        m_profile_predictor_taken = 0;
        m_profile_predictor_correct = 0;
        m_profile_predictor_mispredict = 0;
        m_profile_predictor_recover = 0;
        m_profile_redirect = 0;
        m_profile_interrupt = 0;
        m_profile_issue_blocked = 0;
        m_workload_profile_active = false;
        m_workload_profile_start_seen = false;
        m_workload_profile_end_seen = false;
        m_workload_profile_start_step = 0;
        m_predictor_debug = false;
        m_predictor_debug_events = 0;
        reset_workload_profile();
        const char *irq_cycle = getenv("IRQ_CYCLE");
        if (irq_cycle && *irq_cycle)
            m_irq_cycle = strtol(irq_cycle, NULL, 0);
        const char *predictor_debug = getenv("PREDICTOR_DEBUG");
        if (predictor_debug && !strcmp(predictor_debug, "1"))
            m_predictor_debug = true;

        m_dut = new riscv_tcm_top_rtl("DUT");
        m_dut->clk_in(clk);
        m_dut->rst_in(rst);
        m_dut->rst_cpu_in(rst_cpu_in);
        m_dut->axi_t_out(axi_t_out);
        m_dut->axi_t_in(axi_t_in);
        m_dut->axi_i_out(axi_i_out);
        m_dut->axi_i_in(axi_i_in);
        m_dut->intr_in(intr_in);
		
		verilator_trace_enable("verilator.vcd", m_dut);
    }
    //-----------------------------------------------------------------
    // Trace
    //-----------------------------------------------------------------
    void add_trace(sc_trace_file * fp, std::string prefix)
    {
        if (!waves_enabled())
            return;

        // Add signals to trace file
        #define TRACE_SIGNAL(a) sc_trace(fp,a,#a);
        TRACE_SIGNAL(clk);
        TRACE_SIGNAL(rst);

        m_dut->add_trace(fp, "");
    }

    //-----------------------------------------------------------------
    // create_memory: Create memory region
    //-----------------------------------------------------------------
    bool create_memory(uint32_t base, uint32_t size, uint8_t *mem = NULL)
    {
        sc_assert(base >= 0x00000000 && ((base + size) < (0x00000000 + (64 * 1024))));
        return true;
    }
    //-----------------------------------------------------------------
    // valid_addr: Check address range
    //-----------------------------------------------------------------
    bool valid_addr(uint32_t addr) { return true; } 
    //-----------------------------------------------------------------
    // write: Write byte into memory
    //-----------------------------------------------------------------
    void write(uint32_t addr, uint8_t data)
    {
        m_dut->m_rtl->v->u_tcm->write(addr, data);
    }
    //-----------------------------------------------------------------
    // write: Read byte from memory
    //-----------------------------------------------------------------
    uint8_t read(uint32_t addr)
    {
        return m_dut->m_rtl->v->u_tcm->read(addr);
    }
    //-----------------------------------------------------------------
    // step: Execute 1 clock cycle
    //-----------------------------------------------------------------
    void step(void)
    {
        if (m_irq_cycle >= 0 && m_step_count == (unsigned)m_irq_cycle)
            intr_in.write(1U);
        else
            intr_in.write(0);
        wait();
        intr_in.write(0);
        auto csrfile = m_dut->m_rtl->v->u_core->u_csr->u_csrfile;
        const bool profile_marker_start = csrfile->get_profile_marker_start();
        const bool profile_marker_end = csrfile->get_profile_marker_end();

        if (profile_marker_start)
        {
            reset_workload_profile();
            m_workload_profile_active = true;
            m_workload_profile_start_seen = true;
            m_workload_profile_end_seen = false;
            m_workload_profile_start_step = m_step_count;
            printf("WSL_WORKLOAD_PROFILE_START step=%u\n", m_step_count);
        }
        else if (profile_marker_end && m_workload_profile_active)
        {
            m_workload_profile_active = false;
            m_workload_profile_end_seen = true;
            m_workload_profile_cycle_count = m_step_count -
                                              m_workload_profile_start_step;
        }

        const bool count_workload = m_workload_profile_active &&
                                    !profile_marker_start &&
                                    !profile_marker_end;
        if (count_workload)
            m_workload_profile_cycle_count++;
        sample_profile(count_workload);
        m_step_count++;
    }
    //-----------------------------------------------------------------
    // reset: Release core from reset
    //-----------------------------------------------------------------
    void reset(uint32_t addr)
    {
        m_step_count = 0;
        m_profile_issue = 0;
        m_profile_retire = 0;
        m_profile_lsu_stall = 0;
        m_profile_pipe_stall = 0;
        m_profile_div_hold = 0;
        m_profile_csr_hold = 0;
        m_profile_load_issue = 0;
        m_profile_store_issue = 0;
        m_profile_mul_issue = 0;
        m_profile_div_issue = 0;
        m_profile_csr_issue = 0;
        m_profile_branch = 0;
        m_profile_branch_taken = 0;
        m_profile_predictor_event = 0;
        m_profile_predictor_taken = 0;
        m_profile_predictor_correct = 0;
        m_profile_predictor_mispredict = 0;
        m_profile_predictor_recover = 0;
        m_profile_redirect = 0;
        m_profile_interrupt = 0;
        m_profile_issue_blocked = 0;
        m_workload_profile_active = false;
        m_workload_profile_start_seen = false;
        m_workload_profile_end_seen = false;
        m_workload_profile_start_step = 0;
        m_predictor_debug_events = 0;
        reset_workload_profile();
        intr_in.write(0);
        rst_cpu_in.write(true);
        wait();
        rst_cpu_in.write(false);
    }

    // Not supported
    bool      get_stopped(void) { return false; } 
    bool      get_fault(void)  { return false; }
    void      set_interrupt(int irq)   { }
    void      enable_trace(uint32_t mask) { }
    uint32_t  get_opcode(void)    { }
    uint32_t  get_pc(void)        { return 0; }
    bool      get_reg_valid(int r){ return 0; }
    uint32_t  get_register(int r) { return 0; }
    int       get_num_reg(void)   { return 32; }
    void      set_register(int r, uint32_t val) { }    
};
