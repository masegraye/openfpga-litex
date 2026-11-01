#!/bin/zsh
# Stage-wise Quartus build of the litex core with cart_ram BRAM.
# Usage: ./quartus-build.zsh [stage]   (map|fit|sta|asm|all, default all)
set -e
cd "$(dirname "$0")"
REPO=/Users/mase/dev/analogue-pocket/engine/external/openfpga-litex
IMG=didiermalenfant/quartus:22.1-apple-silicon
QPF=projects/openFPGA-RISC-V_pocket.qpf
OUT=projects/output_files
STAGE=${1:-all}

run_stage() {
  print -- "=== $1 ($(date +%H:%M:%S)) ==="
  docker run --rm -v "$REPO":/work -w /work "$IMG" \
    "$2" "$QPF" $3 2>&1 | grep -E 'Error|Warning.*M10K|register|Info.*Complete|Elapsed|Fitter|failed' | tail -20
  print -- "=== $1 done ($(date +%H:%M:%S)) ==="
}

if [[ $STAGE == map || $STAGE == all ]]; then
  # Register-count gate: BRAM inference failure shows up as huge FF counts
  docker run --rm -v "$REPO":/work -w /work "$IMG" \
    quartus_map "$QPF" 2>&1 | tail -40
  REGS=$(grep -oE 'registers?[ :]+[0-9,]+' $OUT/*.map.rpt 2>/dev/null | grep -oE '[0-9,]+' | tr -d ',' | head -1)
  print "map: ~$REGS registers (expect < 25000 for healthy BRAM inference)"
fi
if [[ $STAGE == fit || $STAGE == all ]]; then run_stage fit quartus_fit; fi
if [[ $STAGE == sta || $STAGE == all ]]; then run_stage sta quartus_sta; fi
if [[ $STAGE == asm || $STAGE == all ]]; then run_stage asm quartus_asm; fi

print "BITSTREAM: $(ls -la $OUT/*.rbf 2>/dev/null || echo 'not found')"
