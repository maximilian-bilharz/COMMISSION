# Deploying COMMISSION on vast.ai (4x RTX 4090)

## 1. Rent the instance
On [vast.ai](https://vast.ai), search for an offer with:
- **GPU:** 4x RTX 4090 (one instance running all four is simplest — they auto-split the seed space with no overlap).
- **Image:** a CUDA **devel** image so `nvcc` is present, e.g. `nvidia/cuda:12.4.1-devel-ubuntu22.04`.
- **Disk:** 20 GB is plenty.
- **Type:** Interruptible is fine and cheapest — COMMISSION resumes from a fresh random seed on restart, and the server de-dupes.

## 2. Run it
SSH into the instance, then:
```bash
git clone https://github.com/maximilian-bilharz/COMMISSION.git
cd COMMISSION
SHROOM_API_KEY='eyJ...your key...' bash deploy/vast.sh
```
That installs deps, builds (large-biomes + unbounded, `sm_89` for the 4090s), launches the search across all 4 GPUs in tmux session `shroom`, and starts the submitter in session `submit`.

## 3. Monitor
```bash
tail -f run.log        # ips is on the 'total' line each PRINT_INTERVAL
tmux attach -t shroom  # live view; Ctrl-b d to detach
tail -f submit.log     # submissions (200 = accepted)
```

## Options (env vars before the command)
| Var | Default | Meaning |
|-----|---------|---------|
| `SIZE` | `200000000` | min island size (blocks) to log |
| `DEVICES` | `0,1,2,3` | GPUs in one process |
| `MODE` | `lb` | `lb`/`sb` for the submitter (match the build) |
| `LARGE_BIOMES` | `1` | compile-time biome mode |
| `UNBOUND` | `1` | compile-time bound mode (ULB) |
| `START` | random | fixed start seed |
| `THREADS` | all cores | CPU verify workers |

## Single 4-GPU instance vs. four 1-GPU instances
- **One 4-GPU instance (recommended):** run as-is. The four cards share one atomic seed iterator → no overlap, one output file, one submitter.
- **Four separate 1-GPU instances:** run the same command with `DEVICES=0` on each. Leave `START` unset so each picks a random start — overlap is negligible across the 2^64 space, and the server de-dupes anyway.

## Interruptible (spot) with auto-resume
Interruptible instances are ~half price but get **paused when outbid**, which kills the
running process. To auto-resume, put the launch in vast.ai's **On-start Script** (it re-runs
on every start, including after a resume):

1. Rental type: **Interruptible**, set your bid near the shown market rate.
2. Image: a CUDA **devel** image (`nvidia/cuda:12.4.1-devel-ubuntu22.04`).
3. Add env vars in the instance config (Docker options): `-e SHROOM_API_KEY=eyJ...` (and
   optionally `-e SIZE=200000000`).
4. Paste the contents of [`deploy/onstart.sh`](onstart.sh) into the **On-start Script** field.

On first boot it clones, builds, and runs. After an interruption->resume, the on-start script
re-runs; the build is skipped (disk persists, `./main` already exists) so it relaunches in
seconds. `output.txt` also persists, and the submitter re-sends on restart (the server
de-dupes). Each restart picks a fresh random start seed unless you set `START`.

## Notes
- `--size` only changes what gets logged/submitted; it does **not** change ips. Lowering it floods CPU verification (each large-biome flood-fill can use ~2.6 GB RAM), so keep `SIZE` high unless you intend to calibrate.
- To stop paying, **destroy** the instance (a stopped instance still bills for disk).
