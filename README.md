# Project components and how to test them

This repo contains a small fixed-point GAN inference RTL prototype (Q1.7.8). Below are the main components and quick commands to test each one locally using the provided Python scripts and Icarus Verilog (`iverilog` / `vvp`). Run commands from the repository root.

- **Converter (MAT -> hex)**
	- File: `model/mat_to_hex.py`
	- Purpose: convert `trained_simple_gan.mat` into per-row Q1.7.8 hex weight/bias files under `src/mem`.
	- Run:
		```bash
		python model/mat_to_hex.py model/output/trained_simple_gan.mat
		```

- **Reference Python inference**
	- File: `model/inference.py`
	- Purpose: computes the expected fixed-point outputs (Q1.7.8) from the .mat and logs intermediate values.
	- Run (from repo root):
		```bash
		python model/inference.py
		```

- **Activation LUTs**
	- Files: `src/sigmoid_lut.v`, `src/tanh_lut.v`
	- Purpose: 1024-entry ROM LUTs used for activation functions. They read `src/mem/sigmoid_lut_mem.hex` and `src/mem/tanh_lut_mem.hex`.
	- Quick compile & run (self-test TBs exist):
		```bash
		cd src
		iverilog -g2005 -o sim_luts tb_sigmoid_lut.v sigmoid_lut.v ; vvp ./sim_luts
		iverilog -g2005 -o sim_lut_t tb_tanh_lut.v tanh_lut.v ; vvp ./sim_lut_t
		```

- **MAC-PE (and debug variant)**
	- Files: `src/mac_pe_act.v` (MAC+activation), `src/mac_pe_act_dbg.v` (debug printing)
	- Purpose: multiply-accumulate, finalize (right shift by `FRAC`) and activation lookup.
	- Run unit tests / debug TBs:
		```bash
		cd src
		iverilog -g2005 -o sim_mac tb_mac_pe.v mac_pe_act.v sigmoid_lut.v tanh_lut.v ; vvp ./sim_mac
		iverilog -g2005 -o sim_mac_dbg tb_mac_pe_dbg.v mac_pe_act_dbg.v sigmoid_lut.v tanh_lut.v ; vvp ./sim_mac_dbg
		```

- **Systolic row / array (work-in-progress)**
	- Files: `src/systolic_row.v`, `src/systolic_array.v`, plus debug variants `systolic_row_dbg.v` and testbenches under `src/`.
	- Purpose: time-multiplexed row that loads per-row weights and runs the MAC-PE across an input vector; `systolic_array` instantiates multiple rows and packs outputs.
	- Note: Some sequencing issues were found and are being iterated on — use the debug row TB to trace internal MAC cycles.
	- Debug run (recommended):
		```bash
		cd src
		iverilog -g2005 -o sim_row_dbg tb_systolic_row_dbg.v systolic_row_dbg.v mac_pe_act_dbg.v sigmoid_lut.v tanh_lut.v ; vvp ./sim_row_dbg
		```

- **Generator / Discriminator / GAN top**
	- Files: `src/gen_top.v`, `src/disc_top.v`, `src/gan_top.v` and `src/tb_gen.v`, `src/tb_disc.v`, `src/tb_gan.v`.
	- Purpose: top-level sequencing of two-stage generator and discriminator using per-row files in `src/mem`.
	- Run full flow (after generating hex files):
		```bash
		cd src
		iverilog -g2005 -o sim_gan gen_top.v disc_top.v gan_top.v systolic_row.v mac_pe_act.v sigmoid_lut.v tanh_lut.v tb_gan.v ; vvp ./sim_gan
		```

Notes and tips
- The fixed-point format used everywhere is Q1.7.8 (16-bit signed, 8 fractional bits). Python `inference.py` uses the same scaling so you can compare integers and floats directly.
- If you change the `.mat` or weights, re-run `model/mat_to_hex.py` before running the RTL tests.
- If a row/array gives saturated outputs, use the debug MAC and `systolic_row_dbg` TB to print per-cycle `prod`, `acc`, and `finalize` traces.
- Commit only verified source files; simulation binaries (e.g., `sim_*`) and temporary VVP outputs should not be committed.

If you want, I can add small Makefile targets to run these commands consistently. Feel free to tell me which tests you'd like added to `README` or automated next.

# Jimmyahh GANtungan Kunci
## Jimmyahh
