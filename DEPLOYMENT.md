# DEPLOYMENT INSTRUCTIONS - UVM HPC

## 📦 What's Included

Your complete ORCA workflow package:

```
📁 Package Contents:
├── orca_complete_workflow.jl    # Main Julia script (pre-configured)
├── setup_hpc.sh                  # Automated setup script
├── xyz_files/                    # All 5 coordinate files
│   ├── MRD.xyz
│   ├── A07.xyz
│   ├── AB113.xyz
│   ├── SDIII.xyz
│   └── CRD.xyz
└── DEPLOYMENT.md                 # This file
```

## ✅ Pre-Configured Settings

Your script is **ready to use** with these settings:

```
✓ ORCA 6.0.1 path configured
✓ 48 cores per job (PAL48)
✓ 500 GB memory per job
✓ general partition
✓ Water solvent (CPCM) only
✓ Separate scratch directories for better I/O
✓ Email notifications to: Modupe.Omoniyi@uvm.edu
✓ Base directory: /users/m/o/momoniyi/MM
```

## 🚀 Quick Deployment (3 Commands)

### Step 1: Upload Everything to HPC
```bash
# On your local machine
scp -r orca_complete_workflow.jl setup_hpc.sh xyz_files/ \
    Modupe.Omoniyi@vacc-user2.uvm.edu:/users/m/o/momoniyi/MM/
```

### Step 2: Run Setup on HPC
```bash
# SSH to HPC
ssh Modupe.Omoniyi@vacc-user2.uvm.edu

# Go to your directory
cd /users/m/o/momoniyi/MM

# Run setup script
bash setup_hpc.sh
```

Expected output:
```
✓ Directories created
✓ Found: MRD.xyz
✓ Found: A07.xyz
✓ Found: AB113.xyz
✓ Found: SDIII.xyz
✓ Found: CRD.xyz
✓ Setup complete! All files are ready.
```

### Step 3: Run Calculations
```bash
# Verify setup
julia orca_complete_workflow.jl setup-only

# Submit optimization jobs (5 jobs in water)
julia orca_complete_workflow.jl opt-only

# After optimizations complete, submit TD-DFT (140 jobs)
julia orca_complete_workflow.jl tddft-only
```

## 📊 What Gets Calculated

### Phase 1: Geometry Optimizations (5 jobs)
Each system optimized in water:
```
! B3LYP OPT FREQ 6-311G(d,p) def2/J D3BJ RIJCOSX PAL48
! CPCM(Water)

Systems: MRD, A07, AB113, SDIII, CRD
Environment: Water only
Expected time: 8-24 hours per system
```

### Phase 2: TD-DFT Calculations (140 jobs)
For each optimized structure:
```
Methods: TDA, TDDFT, sTDA, sTDDFT (4 methods)
Functionals: BP86, B3LYP, TPSSh, M06, CAM-B3LYP, LC-BLYP, ωB97X (7 functionals)
Excited states: 50 per calculation

Total: 5 systems × 4 methods × 7 functionals = 140 TD-DFT jobs
Expected time: 1-4 hours per calculation
```

## 📁 Directory Structure Created

```
/users/m/o/momoniyi/MM/
├── orca_complete_workflow.jl
├── setup_hpc.sh
│
├── xyz_files/
│   ├── MRD.xyz
│   ├── A07.xyz
│   ├── AB113.xyz
│   ├── SDIII.xyz
│   └── CRD.xyz
│
├── calculations/
│   ├── MRD/
│   │   ├── optimization/
│   │   │   └── water/
│   │   │       ├── MRD_opt_water.inp
│   │   │       ├── MRD_opt_water.out
│   │   │       ├── MRD_opt_water.xyz
│   │   │       ├── MRD_opt_water_slurm.out
│   │   │       └── MRD_opt_water_slurm.err
│   │   └── tddft/
│   │       └── water/
│   │           ├── MRD_TDA_BP86_water.inp
│   │           ├── MRD_TDA_B3LYP_water.inp
│   │           └── ... (28 TD-DFT calculations)
│   ├── A07/
│   ├── AB113/
│   ├── SDIII/
│   └── CRD/
│
├── job_scripts/
│   ├── MRD/
│   │   ├── MRD_opt_water.sh
│   │   ├── MRD_TDA_BP86_water.sh
│   │   └── ...
│   └── ... (all SLURM scripts)
│
└── analysis_results/
    ├── optimization_summary.txt
    └── tddft_summary.csv
```

## 🎯 Usage Commands

```bash
# Check setup
julia orca_complete_workflow.jl setup-only

# Submit optimization jobs (5 jobs)
julia orca_complete_workflow.jl opt-only

# Submit TD-DFT jobs (140 jobs) - after optimizations complete
julia orca_complete_workflow.jl tddft-only

# Analyze results
julia orca_complete_workflow.jl analyze

# Get help
julia orca_complete_workflow.jl help
```

## 🔍 Monitoring Your Jobs

### Check SLURM Queue
```bash
squeue -u Modupe.Omoniyi
```

### Watch Real-Time Progress
```bash
# Watch optimization
tail -f calculations/AB113/optimization/water/AB113_opt_water.out

# Check for completion
grep "TERMINATED NORMALLY" calculations/*/optimization/water/*.out

# Count completed jobs
grep -l "TERMINATED NORMALLY" calculations/*/*/*/*.out | wc -l
```

### View SLURM Output
```bash
# Check SLURM stdout
cat calculations/AB113/optimization/water/AB113_opt_water_slurm.out

# Check SLURM errors
cat calculations/AB113/optimization/water/AB113_opt_water_slurm.err
```

## 💡 Key Features

### ✅ Separate Scratch Directories
Each job runs in `/tmp/${SLURM_JOB_ID}_jobname/` for better I/O:
- Avoids network filesystem bottlenecks
- Faster read/write operations
- Results automatically copied back after completion

### ✅ Email Notifications
You'll receive emails at `Modupe.Omoniyi@uvm.edu` for:
- Job starts
- Job completions
- Job failures

### ✅ Water Solvent Only
All calculations use `CPCM(Water)` implicit solvation:
- Optimizations in water
- TD-DFT in water
- Mimics aqueous environment

## 📊 Expected Resources

### Disk Space
- Per optimization: ~2-5 GB
- Per TD-DFT: ~500 MB - 2 GB
- **Total needed: ~300-500 GB**

### Computation Time
- 5 optimizations: 40-120 hours total (can run parallel)
- 140 TD-DFT: 140-560 hours total (can run parallel)
- **Wall time: 2-4 days** if all run in parallel

### Memory Usage
- 500 GB per job
- ~10.4 GB per core (500/48)
- ORCA uses `%maxcore 10666` MB per core

## ⚙️ Customization Options

If you need to modify settings, edit `orca_complete_workflow.jl`:

### Change Number of Processors
Line 20:
```julia
const NPROCS = 48        # Change to 24, 36, etc.
```

### Test with Fewer Functionals
Line 38:
```julia
const FUNCTIONALS = ["B3LYP", "CAM-B3LYP"]  # Just 2 for quick test
```

### Change Basis Set
Line 34:
```julia
const OPT_BASIS = "def2-SVP"  # Smaller/faster
```

### Disable Email Notifications
Line 22:
```julia
const EMAIL_ADDRESS = ""  # Leave blank
```

## 🔧 Troubleshooting

### Julia Not Found
```bash
module load julia
# or ask HPC support for Julia installation
```

### Job Fails Immediately
```bash
# Check SLURM error
cat calculations/*/optimization/water/*_slurm.err

# Common fixes:
# 1. Verify ORCA module loads: module load orca/6.0.1
# 2. Check disk quota: myquota
# 3. Verify scratch space: df -h /tmp
```

### Optimization Won't Converge
```bash
# Check last 100 lines
tail -100 calculations/MRD/optimization/water/MRD_opt_water.out

# Look for:
# - SCF convergence issues
# - Geometry problems
# - Imaginary frequencies
```

### Wrong xyz Files Uploaded
```bash
# Check current files
ls -lh /users/m/o/momoniyi/MM/xyz_files/

# Replace if needed
cp /correct/path/*.xyz /users/m/o/momoniyi/MM/xyz_files/
```

## 📈 After Calculations Complete

### Extract All Results
```bash
cd /users/m/o/momoniyi/MM
julia orca_complete_workflow.jl analyze
```

This creates:
- `analysis_results/optimization_summary.txt` - Energies, convergence status
- `analysis_results/tddft_summary.csv` - All excitation data

### Download Results to Your Computer
```bash
# From your local machine
scp -r Modupe.Omoniyi@vacc-user2.uvm.edu:/users/m/o/momoniyi/MM/analysis_results .
```

### Import to Python/Excel
```python
import pandas as pd

# Load TD-DFT results
df = pd.read_csv('analysis_results/tddft_summary.csv')

# Find brightest transition for each functional
brightest = df.loc[df.groupby(['System', 'Functional'])['OscStrength'].idxmax()]

# Plot absorption spectra
import matplotlib.pyplot as plt
for system in df['System'].unique():
    system_data = df[df['System'] == system]
    plt.figure()
    for func in df['Functional'].unique():
        func_data = system_data[system_data['Functional'] == func]
        plt.scatter(func_data['Wavelength_nm'], func_data['OscStrength'], 
                   label=func, alpha=0.6)
    plt.xlabel('Wavelength (nm)')
    plt.ylabel('Oscillator Strength')
    plt.title(f'{system} - TD-DFT Comparison')
    plt.legend()
    plt.savefig(f'{system}_tddft.png')
```

## 📞 Support

**UVM HPC Support:**
- Website: https://www.uvm.edu/vacc
- Email: vacc@uvm.edu
- Hours: Monday-Friday, 8am-5pm EST

**Script Issues:**
- Run help: `julia orca_complete_workflow.jl help`
- Check logs in `calculations/`

## 🎓 Citation

When publishing, cite:
- ORCA 6: Neese, F. et al. *J. Chem. Phys.* 2024
- B3LYP: Becke, A.D. *J. Chem. Phys.* 1993; Lee, C. et al. *Phys. Rev. B* 1988
- D3BJ: Grimme, S. et al. *J. Chem. Phys.* 2010; *J. Comput. Chem.* 2011
- RIJCOSX: Neese, F. et al. *Chem. Phys.* 2009
- CPCM: Barone, V. and Cossi, M. *J. Phys. Chem. A* 1998

---

## ✨ You're Ready!

Everything is configured and ready to run. Just upload, run setup, and submit! 🚀
