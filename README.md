# AXI4-Lite to APB4 Bridge

## Overview
This project is a SystemVerilog implementation and verification suite for an **AXI4-Lite to APB4 Bridge** connected to a custom **APB4 Control & Status Register (CSR)** block.

In an SoC, the main system bus usually runs on AXI, while simpler peripherals like timers, UARTs, or CSR blocks run on APB to save area and power. This bridge sits between the two, translating single-beat, memory-mapped AXI4-Lite reads and writes into two-phase APB4 transfers. It keeps byte write strobes intact, handles wait states and backpressure from either side, and passes peripheral errors back to the AXI master.

---

## Key Features
* **AXI4-Lite Subordinate Interface:** 32-bit address and data widths across all five independent channels (`AW`, `W`, `B`, `AR`, `R`) using standard `VALID`/`READY` handshakes.
* **Decoupled Write Channels:** Independently latches the Write Address (`AW`) and Write Data (`W`) channels so staggered arrivals do not hang the bus.
* **APB4 Requester Interface:** Drives standard `SETUP` and `ACCESS` phases with full 4-bit byte-lane write strobe (`PSTRB`) support.
* **Error Handling:** Catches `PSLVERR` from the APB peripheral (unmapped addresses or writes to read-only registers) and translates it to `AXI_RESP_SLVERR` (`2'b10`) on `BRESP`/`RRESP`.
* **SystemVerilog Assertions (SVA):** Bound directly to the bridge and CSR instances to monitor AXI/APB protocol rules during simulation.

---

## How It Works

### AXI4-Lite Interface
All five channels use a two-way `VALID`/`READY` handshake. A transfer happens on the rising clock edge when both signals are high:
1. **Write Address (`AW`):** Target write address.
2. **Write Data (`W`):** 32-bit write data and 4-bit byte strobe (`WSTRB`).
3. **Write Response (`B`):** Write status (`OKAY` or `SLVERR`).
4. **Read Address (`AR`):** Target read address.
5. **Read Data (`R`):** 32-bit read data and read status (`OKAY` or `SLVERR`).

### APB4 Interface
Each APB4 transfer takes two clock cycles (assuming `PREADY = 1`):
1. **SETUP Phase (`PSELx = 1, PENABLE = 0`):** Drives `PADDR`, `PWRITE`, `PWDATA`, and `PSTRB` onto the bus for one cycle.
2. **ACCESS Phase (`PSELx = 1, PENABLE = 1`):** Holds all signals stable until `PREADY = 1`, then samples `PRDATA` and `PSLVERR`.

### Backpressure Handling
* **Response Stalls:** If the AXI master holds `BREADY` or `RREADY` low, the bridge holds `BVALID`/`RVALID` and the registered response payload stable until the handshake finishes.
* **Busy Bridge:** While an APB transfer is in progress (`APB_SETUP` or `APB_ACCESS`), the bridge deasserts `AWREADY`, `WREADY`, and `ARREADY` so new requests wait cleanly.
* **APB Wait States:** If a peripheral holds `PREADY` low during `APB_ACCESS`, the FSM stays in `APB_ACCESS` and keeps all APB signals locked until `PREADY` goes high.

---

## Block Diagram
The top-level wrapper (`bridge_top`) connects the AXI4-Lite to APB4 Bridge (`u_bridge`) to the APB4 CSR (`u_csr`).

![AXI4-Lite to APB4 Bridge Block Diagram](images/block_diagram.png)

---

## FSM Architecture
A 3-state FSM controls the APB side of the bridge:

1. **`APB_IDLE`:** Waits for either a read handshake (`AR`) or both write channels (`AW` and `W`) to be latched.
2. **`APB_SETUP`:** Asserts `PSELx = 1` and `PENABLE = 0` for one cycle while driving the latched address, write data, and strobes.
3. **`APB_ACCESS`:** Asserts `PENABLE = 1`. Once `PREADY` is high, latches `PRDATA`/`PSLVERR`, drives `BVALID` or `RVALID`, and returns to `APB_IDLE`.

![Bridge FSM State Diagram](images/fsm_diagram.png)

---

## APB4 CSR Register Map
The `apb_csr.sv` module is used to test reads, writes, byte strobes, and error responses end-to-end.

| Offset | Register | Access | Description |
| :--- | :--- | :--- | :--- |
| `0x00` | `CTRL` | R/W | Control register |
| `0x04` | `STATUS` | RO | Read-only status register (writes trigger `PSLVERR`) |
| `0x08` | `CONFIG` | R/W | Configuration register |`0x08` | `CONFIG` | R/W | Configuration register |
| `0x0C` | `TEMP` | R/W | Testing Register used for read/write testing |
| *Other* | *Unmapped* | N/A | Triggers `PSLVERR` -> translated to `AXI_RESP_SLVERR` |

---

## Verification & SVAs
The design is simulated in **AMD Vivado XSim** using a directed testbench (`bridge_tb.sv`) with clock-aligned `axi_write` and `axi_read` tasks. Both tasks take delay inputs to simulate AXI master wait states and backpressure.

### Bound SVA Modules
* **`axi_to_apb_bridge_sva.sv` (bound to `u_bridge`):**
  * **AXI4-Lite Handshake & Payload Stability:** Verifies that once `VALID` is asserted on any channel (`AW`, `W`, `B`, `AR`, `R`), both `VALID` and its associated payload (`AWADDR`, `WDATA`, `WSTRB`, `ARADDR`, `BRESP`, `RDATA`, `RRESP`) remain stable until the corresponding `READY` handshake completes.
  * **APB4 Phase Sequencing:** Checks that `PSELx` transitions cleanly from `SETUP` (`PENABLE = 0`) to `ACCESS` (`PENABLE = 1`), and that `PENABLE` is never asserted without `PSELx`.
  * **Error Translation:** Confirms that an APB `PSLVERR` sampled during `ACCESS` maps to `AXI_RESP_SLVERR` (`2'b10`) on `BRESP` or `RRESP`.
  * **Reset Behavior:** Ensures AXI `VALID` and APB control signals (`PSELx`, `PENABLE`) deassert cleanly on reset.
* **`apb_csr_sva.sv` (bound to `u_csr`):**
  * **APB4 Protocol Compliance:** Verifies proper `SETUP`-to-`ACCESS` timing (`PENABLE` only asserts the cycle after `PSELx && !PENABLE`), checks that `PADDR`, `PWRITE`, `PWDATA`, and `PSTRB` remain stable while waiting for `PREADY`, and ensures `PSLVERR` is only asserted during a valid `ACCESS` transfer (`PSELx && PENABLE && PREADY`).
  * **Address Decoding & Access Protection:** Confirms that accesses to unmapped addresses assert `PSLVERR`, and that illegal writes to the read-only `STATUS` register (`0x04`) assert `PSLVERR` while leaving the register value unchanged.

### Directed Test Cases
1. **Zero-Delay Write/Read:** Baseline write and readback to `TEMP` (`0x0C`) with zero wait states.
2. **Staggered Write Channels:** Delays `WVALID` after `AWVALID` and delays `BREADY` to verify decoupled write latching.
3. **Backpressured Read:** Holds `RREADY` low for 5 cycles to confirm `RVALID` and `RDATA` stay stable.
4. **Unmapped Address Write:** Writes to `0x10` and checks for `AXI_RESP_SLVERR`.
5. **Read-Only Register Write:** Attempts to write to `STATUS` (`0x04`) and checks for `AXI_RESP_SLVERR`.
6. **Back-to-Back Recovery:** Runs a normal write and read to `CTRL` (`0x00`) right after the error tests to make sure the FSM recovers cleanly.

### Vivado XSim Waveforms from Test Cases


---
## Project Structure
```text
axi4-lite-to-apb-bridge/
├── docs/
│   └── APB4_Operating_States.png     # APB4 operating state diagram
├── rtl/
│   ├── axi_to_apb_bridge_pkg.sv      # Parameters, typedefs, and AXI response enums
│   ├── axi_to_apb_bridge.sv          # AXI4-Lite to APB4 Bridge RTL
│   ├── apb_csr.sv                    # APB4 CSR peripheral
│   └── bridge_top.sv                 # Top-level wrapper
├── scripts/
│   ├── full_bridge_sim.tcl           # Full bridge Vivado XSim build and run script
│   └── run_apb_csr.tcl               # Standalone APB CSR simulation script
├── sim/
│   ├── sva/
│   │   ├── axi_to_apb_bridge_sva.sv  # Bridge protocol SVAs (bound to u_bridge)
│   │   └── apb_csr_sva.sv            # CSR SVAs (bound to u_csr)
│   └── tb/
│       ├── apb_csr_tb.sv             # Standalone APB CSR testbench
│       └── bridge_tb.sv              # Top-level directed testbench and SVA bindings
└── README.md
```

---

## How to Run
1. Clone the repo:
   ```sh
   git clone [https://github.com/migueloctavo26/axi4-lite-to-apb-bridge.git](https://github.com/migueloctavo26/axi4-lite-to-apb-bridge.git)
   cd axi4-lite-to-apb-bridge
   ```
2. Open **AMD Vivado** and `cd` into the repo directory in the Tcl Console:
   ```tcl
   cd /path/to/axi4-lite-to-apb-bridge
   ```
3. Run the simulation script:
   ```tcl
   source scripts/full_bridge_sim.tcl
   ```
4. Check the Tcl Console for all passing test logs (with zero SVA `$error` messages) and inspect the signals in the waveform viewer.

---

## References
1. [ARM AMBA AXI and ACE Protocol Specification (AXI4-Lite)](https://developer.arm.com/documentation/ihi0022/latest/)
2. [ARM AMBA APB Protocol Specification (APB4)](https://developer.arm.com/documentation/ihi0024/latest/)