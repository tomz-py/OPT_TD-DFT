# ORCA Workflow - Your UVM HPC Setup

## ✅ Pre-Configured for Your System

The script is **already configured** with your HPC settings:

```julia
ORCA Path:    /gpfs1/sw/rh9/pkgs/stacks/gcc/13.3.0/mpi-pkgs/openmpi/5.0.5/orca/6.0.1/orca
Partition:    general
Processors:   48 cores per job
Memory:       500 GB per job
Walltime:     48:00:00
Email:        Modupe.Omoniyi@uvm.edu
Modules:      gcc/13.3.0-xp3epyt, openmpi/5.0.5, orca/6.0.1
```

## 🚀 Quick Start (3 Steps)

### Step 1: Upload and Prepare
```bash
# Upload to UVM HPC
scp orca_complete_workflow.jl Modupe.Omoniyi@vacc-user2.uvm.edu:~/

# SSH to cluster
ssh Modupe.Omoniyi@vacc-user2.uvm.edu

# Create directory for coordinate files
mkdir xyz_files

# Copy your .xyz files (adjust paths as needed)
cp /path/to/your/MRD.xyz xyz_files/
cp /path/to/your/A07.xyz xyz_files/
cp /path/to/your/AB113.xyz xyz_files/
cp /path/to/your/SDIII.xyz xyz_files/
cp /path/to/your/CRD.xyz xyz_files/
```

### Step 2: Verify Setup
```bash
julia orca_complete_workflow.jl setup-only
```

Expected output:
```
✓ MRD: Ready (found MRD.xyz)
✓ A07: Ready (found A07.xyz)
✓ AB113: Ready (found AB113.xyz)
✓ SDIII: Ready (found SDIII.xyz)
✓ CRD: Ready (found CRD.xyz)
```

### Step 3: Submit Jobs
```bash
# Submit geometry optimizations
julia orca_complete_workflow.jl opt-only

# You'll get email notifications when jobs complete!
# Then submit TD-DFT calculations:
julia orca_complete_workflow.jl tddft-only
```

## 📊 Generated SLURM Scripts

The script generates SLURM files **exactly like yours**:

```bash
#!/bin/bash
#SBATCH --job-name=AB113_opt_gas
#SBATCH -o AB113_opt_gas_slurm.out
#SBATCH -e AB113_opt_gas_slurm.err
#SBATCH --partition=general
#SBATCH -N 1
#SBATCH -n 48
#SBATCH --mem=500G
#SBATCH --time=48:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=Modupe.Omoniyi@uvm.edu

module purge
module load gcc/13.3.0-xp3epyt openmpi/5.0.5 orca/6.0.1

cd orca_calculations/AB113/optimization/gas
/gpfs1/sw/rh9/pkgs/stacks/gcc/13.3.0/mpi-pkgs/openmpi/5.0.5/orca/6.0.1/orca AB113_opt_gas.inp > AB113_opt_gas.out
```

## 📁 File Organization

```
Your_Directory/
├── orca_complete_workflow.jl       # The main script
├── xyz_files/                       # Your input coordinates
│   ├── MRD.xyz
│   ├── A07.xyz
│   ├── AB113.xyz
│   ├── SDIII.xyz
│   └── CRD.xyz
│
├── orca_calculations/               # All outputs (auto-created)
│   ├── MRD/
│   │   ├── optimization/
│   │   │   ├── gas/
│   │   │   │   ├── MRD_opt_gas.inp
│   │   │   │   ├── MRD_opt_gas.out
│   │   │   │   ├── MRD_opt_gas_slurm.out
│   │   │   │   ├── MRD_opt_gas_slurm.err
│   │   │   │   └── MRD_opt_gas.xyz
│   │   │   └── chloroform/
│   │   └── tddft/
│   │       ├── gas/
│   │       │   ├── MRD_TDA_BP86_gas.inp
│   │       │   ├── MRD_TDA_B3LYP_gas.inp
│   │       │   └── ... (28 calculations per environment)
│   │       └── chloroform/
│   └── ... (other systems)
│
├── job_scripts/                     # SLURM scripts (auto-created)
│   ├── MRD/
│   │   ├── MRD_opt_gas.sh
│   │   ├── MRD_opt_chloroform.sh
│   │   ├── MRD_TDA_BP86_gas.sh
│   │   └── ...
│   └── ...
│
└── analysis_results/                # Results (after running analyze)
    ├── optimization_summary.txt
    └── tddft_summary.csv
```

## 📧 Email Notifications

You'll receive emails for:
- ✅ Job starts
- ✅ Job completes
- ✅ Job fails

Check your email: **Modupe.Omoniyi@uvm.edu**

## 🔍 Monitoring Your Jobs

### Check SLURM Queue
```bash
squeue -u Modupe.Omoniyi
```

### Watch Real-Time Progress
```bash
# Watch optimization
tail -f orca_calculations/AB113/optimization/gas/AB113_opt_gas.out

# Count completed jobs
grep -l "TERMINATED NORMALLY" orca_calculations/*/*/*/*.out | wc -l
```

### Check for Errors
```bash
# View SLURM errors
cat orca_calculations/AB113/optimization/gas/AB113_opt_gas_slurm.err

# Check ORCA output for issues
grep -i "error\|abort\|fatal" orca_calculations/*/*/*/*.out
```

## 📈 What Gets Calculated

### Geometry Optimizations (10 jobs)
**For each of your 5 systems:**
- Gas phase calculation
- Chloroform (CPCM) calculation

**Settings:**
```
! B3LYP OPT FREQ 6-311G(d,p) def2/J D3BJ RIJCOSX PAL48
```

**Memory per core:** ~10.7 GB (512GB / 48 cores)
**Expected time:** 6-24 hours per system

### TD-DFT Calculations (280 jobs)
**For each system in each environment:**
- 4 methods: TDA, TDDFT, sTDA, sTDDFT
- 7 functionals: BP86, B3LYP, TPSSh, M06, CAM-B3LYP, LC-BLYP, ωB97X
- 50 excited states each

**Expected time:** 1-6 hours per calculation

### Total Resources
- **290 jobs** total
- **~10-15 TB** disk space needed
- **2-4 days** wall time (if all run in parallel)

## 🎯 Usage Commands

| Command | What It Does |
|---------|--------------|
| `julia orca_complete_workflow.jl setup-only` | Check files and create directories |
| `julia orca_complete_workflow.jl opt-only` | Submit 10 optimization jobs |
| `julia orca_complete_workflow.jl tddft-only` | Submit 280 TD-DFT jobs |
| `julia orca_complete_workflow.jl analyze` | Extract results to CSV |
| `julia orca_complete_workflow.jl help` | Show help |

## ⚙️ Customization (Optional)

If you want to modify settings, edit these lines in the script:

### Change to Gas Phase Only
Line 27:
```julia
const ENVIRONMENTS = ["gas"]  # Remove chloroform
```
This reduces jobs to: 5 opt + 140 TD-DFT = **145 total jobs**

### Test with Fewer Functionals
Line 38:
```julia
const FUNCTIONALS = ["B3LYP", "CAM-B3LYP"]  # Just 2 for testing
```

### Adjust Resources Per Job
Lines 19-21:
```julia
const NPROCS = 48        # Processors per job
const MEMORY_MB = 512000 # Memory per job (500 GB)
const SLURM_TIME = "48:00:00"
```

### Change Email Notifications
Line 22:
```julia
const EMAIL_ADDRESS = "different.email@uvm.edu"
```

## 🔧 Troubleshooting

### Job Fails Immediately
```bash
# Check SLURM error file
cat orca_calculations/*/optimization/gas/*_slurm.err

# Common issues:
# 1. Module not available → contact HPC support
# 2. ORCA path wrong → verify installation
# 3. Out of quota → check disk space with `myquota`
```

### Optimization Won't Converge
```bash
# Check the output
tail -100 orca_calculations/MRD/optimization/gas/MRD_opt_gas.out

# Try:
# - Verify starting geometry is reasonable
# - Check for clashes or unrealistic bonds
# - Consider starting with smaller basis set
```

### Can't Find Julia
```bash
# Load Julia module
module load julia

# Or install locally if needed
# Contact HPC support for help
```

## 📊 Analyzing Results

After calculations complete:

```bash
# Extract all data to CSV
julia orca_complete_workflow.jl analyze

# Open in Excel or import to Python
cat analysis_results/tddft_summary.csv

# Python analysis example:
# import pandas as pd
# df = pd.read_csv('analysis_results/tddft_summary.csv')
# df.groupby(['System', 'Functional'])['Wavelength_nm'].mean()
```

## 💾 Backup Important Files

```bash
# After calculations complete, backup:
tar -czf orca_results_$(date +%Y%m%d).tar.gz \
    orca_calculations/*/*/*/*.xyz \
    orca_calculations/*/*/*/*.out \
    analysis_results/

# Copy to your local machine
scp Modupe.Omoniyi@vacc-user2.uvm.edu:~/orca_results_*.tar.gz .
```

## 📞 Support

**HPC Issues:**
- UVM VACC Help: https://www.uvm.edu/vacc
- Email: vacc@uvm.edu

**Script Questions:**
- Check help: `julia orca_complete_workflow.jl help`
- Review output files in `orca_calculations/`

## 🎓 Citation

When publishing, cite:
- ORCA 6: Neese, F. *J. Chem. Phys.* 2024 (check latest reference)
- DFT functionals used
- Basis sets and dispersion corrections

---

**Everything is ready to go! Just add your .xyz files and run.** ✨
