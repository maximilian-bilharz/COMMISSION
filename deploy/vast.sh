#!/usr/bin/env bash
# One-command deploy for COMMISSION on a vast.ai instance (e.g. 4x RTX 4090).
#
# On the instance (a CUDA *devel* image, so nvcc is present):
#   git clone https://github.com/maximilian-bilharz/COMMISSION.git
#   cd COMMISSION
#   SHROOM_API_KEY='eyJ...your key...' bash deploy/vast.sh
#
# Optional overrides (env vars):
#   DEVICES=0,1,2,3   GPUs to use in one process (auto-splits seeds, no overlap)
#   SIZE=200000000    min island size to log (blocks)
#   START=<seed>      fixed start seed (default: random, good for parallel rigs)
#   MODE=lb           lb=large biomes, sb=small biomes (must match the build)
#   ARCH=sm_89        RTX 4090 = Ada Lovelace (sm_89)
#   LARGE_BIOMES=1    1=large biomes, 0=small   (compile-time)
#   UNBOUND=1         1=unbounded (ULB), 0=within world border (compile-time)
#   THREADS=<n>       CPU verify workers (default: all cores)
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root

DEVICES="${DEVICES:-0,1,2,3}"
SIZE="${SIZE:-200000000}"
START="${START:-}"
MODE="${MODE:-lb}"
ARCH="${ARCH:-sm_89}"
LARGE_BIOMES="${LARGE_BIOMES:-1}"
UNBOUND="${UNBOUND:-1}"
THREADS="${THREADS:-$(nproc)}"

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "== installing deps =="
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq build-essential tmux git python3 python3-pip >/dev/null
pip3 install -q requests 2>/dev/null || pip3 install -q --break-system-packages requests

if [ -x ./main ] && [ -z "${FORCE_BUILD:-}" ]; then
  echo "== ./main already built, skipping (set FORCE_BUILD=1 to rebuild) =="
else
  echo "== building (ARCH=$ARCH LARGE_BIOMES=$LARGE_BIOMES UNBOUND=$UNBOUND) =="
  make -B ARCH="$ARCH" LARGE_BIOMES="$LARGE_BIOMES" UNBOUND="$UNBOUND"
fi
test -x ./main || { echo "build failed: ./main not found"; exit 1; }

START_ARG=""; [ -n "$START" ] && START_ARG="--start $START"

echo "== launching search on GPUs $DEVICES (tmux session 'shroom') =="
tmux kill-session -t shroom 2>/dev/null || true
tmux new-session -d -s shroom -c "$PWD" \
  "./main --device $DEVICES --threads $THREADS --size $SIZE $START_ARG --output output.txt 2>&1 | tee run.log"

if [ -n "${SHROOM_API_KEY:-}" ]; then
  echo "== launching submitter (tmux session 'submit') =="
  [ -d shroomin-server ] || git clone --depth 1 https://github.com/BoySanic/shroomin-server.git
  tmux kill-session -t submit 2>/dev/null || true
  tmux new-session -d -s submit -c "$PWD" \
    "python3 shroomin-server/client.py '$SHROOM_API_KEY' '$MODE' 2>&1 | tee submit.log"
else
  echo "!! SHROOM_API_KEY not set -> searching but NOT submitting. Re-run with the key to submit."
fi

cat <<EOF

Deployed.
  search log : tail -f $PWD/run.log     (or: tmux attach -t shroom)
  submit log : tail -f $PWD/submit.log  (or: tmux attach -t submit)
  detach tmux: Ctrl-b then d
  ips shows in run.log every PRINT_INTERVAL iterations on the 'total' line.
EOF
