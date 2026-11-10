# ==============================================================================
# File: scripts/run_apb_csr.tcl
# ==============================================================================

set PROJECT_ROOT [pwd]

set RTL_DIR  [file normalize "$PROJECT_ROOT/rtl"]
set SVA_DIR  [file normalize "$PROJECT_ROOT/sim/sva"]
set TB_DIR   [file normalize "$PROJECT_ROOT/sim/tb"]
set WORK_DIR [file normalize "$PROJECT_ROOT/sim_work"]

if {![file exists "$TB_DIR/apb_csr_tb.sv"]} {
    puts "\[Vivado TCL Error\] Cannot find testbench at: $TB_DIR/apb_csr_tb.sv"
    return
}

# 1. Close active simulation session if one is currently open
if {[current_sim] ne ""} {
    puts "\[Vivado TCL\] Closing existing simulation session..."
    close_sim -force
}

# 2. Clean and prepare workspace
puts "\[Vivado TCL\] Preparing workspace: $WORK_DIR"
if {[file exists $WORK_DIR]} {
    # If file deletion fails due to OS lock, catch it gracefully
    if {[catch {file delete -force $WORK_DIR} del_err]} {
        puts "\[Vivado TCL Warning\] Could not completely delete sim_work (file locked). Cleaning contents..."
    }
}
file mkdir $WORK_DIR
cd $WORK_DIR

# 3. Compile SystemVerilog sources
puts "\[Vivado TCL\] Compiling sources..."
exec xvlog -sv -i $RTL_DIR \
    "$RTL_DIR/axi_to_apb_bridge_pkg.sv" \
    "$RTL_DIR/apb_csr.sv" \
    "$SVA_DIR/apb_csr_sva.sv" \
    "$TB_DIR/apb_csr_tb.sv"

# 4. Elaborate design snapshot
puts "\[Vivado TCL\] Elaborating snapshot..."
exec xelab -L xil_defaultlib work.apb_csr_tb -s apb_csr_tb_sim -debug typical

# 5. Load & Run inside sim_work
puts "\[Vivado TCL\] Loading simulation engine..."
xsim apb_csr_tb_sim

puts "\[Vivado TCL\] Adding signals to wave viewer..."
add_wave /apb_csr_tb/*

puts "\[Vivado TCL\] Running testbench..."
run -all

# 6. Restore working directory back to project root
cd $PROJECT_ROOT