# Vivado Simulation Tcl Script for AXI-to-APB Subsystem
# Run from the root directory: source scripts/full_bridge_sim.tcl

set project_name "axi_apb_sim_proj"
set project_dir "./$project_name"

create_project $project_name $project_dir -force

# 1. Add Design Sources (pointing to the rtl/ folder)
# The package MUST be listed first!
add_files -fileset sources_1 [list \
    rtl/axi_to_apb_bridge_pkg.sv \
    rtl/axi_to_apb_bridge.sv \
    rtl/apb_csr.sv \
    rtl/bridge_top.sv \
]

# 2. Add Simulation Sources (pointing to the sim/tb/ folder)
# 2. Add Simulation Sources (pointing to the sim/tb/ folder)
add_files -fileset sim_1 [list \
    sim/sva/axi_to_apb_bridge_sva.sv \
    sim/sva/apb_csr_sva.sv \
    sim/tb/bridge_tb.sv \
]
# 3. Force Vivado to treat them all strictly as SystemVerilog
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sources_1]]
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1]]

# 4. Set the top-level modules
set_property top bridge_top [current_fileset]
set_property top tb_bridge_top [get_filesets sim_1]

# 5. Let Vivado build the hierarchy
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# 6. Launch the Vivado Simulator (xsim) and run
launch_simulation
run all