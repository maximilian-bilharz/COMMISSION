#!/usr/bin/env bash
# vast.ai "On-start Script" for interruptible instances.
# Paste this whole block into the On-start Script field, and set these
# environment variables in the instance config (Docker options: -e NAME=value):
#   SHROOM_API_KEY=eyJ...        (required, to submit)
#   SIZE=200000000               (optional)
#   LARGE_BIOMES=1  UNBOUND=1    (optional, defaults already these)
#
# This re-runs on every (re)start, so after an interruption->resume the search
# relaunches automatically. The build is skipped if ./main already exists
# (the disk persists across pause/resume), so resumes are fast.
set -e
cd /root 2>/dev/null || cd /
[ -d COMMISSION ] || git clone https://github.com/maximilian-bilharz/COMMISSION.git
cd COMMISSION
git pull --ff-only 2>/dev/null || true
bash deploy/vast.sh
