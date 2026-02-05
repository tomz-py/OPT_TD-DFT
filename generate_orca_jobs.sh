#!/bin/bash

# ORCA Workflow Generator - Pure Bash Version
# No Julia required!

echo "============================================================================"
echo "ORCA Workflow Setup - Generating Input Files"
echo "============================================================================"

# Configuration
BASE_DIR="/users/m/o/momoniyi/MM"
ORCA_PATH="/gpfs1/sw/rh9/pkgs/stacks/gcc/13.3.0/mpi-pkgs/openmpi/5.0.5/orca/6.0.1/orca"
NPROCS=48
MEMORY_GB=500
EMAIL="Modupe.Omoniyi@uvm.edu"

# Systems to calculate
SYSTEMS=("MRD" "A07" "AB113" "SDIII" "CRD")

# Create directory structure
echo ""
echo "Creating directories..."
mkdir -p ${BASE_DIR}/calculations
mkdir -p ${BASE_DIR}/job_scripts

for system in "${SYSTEMS[@]}"; do
    mkdir -p ${BASE_DIR}/calculations/${system}/optimization/water
    mkdir -p ${BASE_DIR}/calculations/${system}/tddft/water
    mkdir -p ${BASE_DIR}/job_scripts/${system}
done
echo "✓ Directories created"

# Function to generate optimization input file
generate_opt_input() {
    local system=$1
    local output_file=$2
    
    cat > ${output_file} << EOF
## ORCA input file for ${system} optimization
# Generated: $(date)
# Environment: water
# 
! B3LYP OPT FREQ 6-311G(d,p) def2/J D3BJ RIJCOSX PAL${NPROCS}
! CPCM(Water)

%maxcore $(( (MEMORY_GB * 1024) / NPROCS ))

%scf
	MaxIter 5000
	CNVDIIS 1
	CNVSOSC 1
end

%geom
	MaxIter 500
	TolE 5e-6
	TolRMSG 1e-4
	TolMaxG 3e-4
end

%output
	print[p_mos] true
	print[p_basis] 5
end

*xyzfile 0 1 ${system}.xyz
EOF
}

# Function to generate SLURM script
generate_slurm_script() {
    local job_name=$1
    local input_file=$2
    local output_dir=$3
    local slurm_file=$4
    
    cat > ${slurm_file} << EOF
#!/bin/bash
#SBATCH --job-name=${job_name}
#SBATCH -o ${job_name}_slurm.out
#SBATCH -e ${job_name}_slurm.err
#SBATCH --partition=general
#SBATCH -N 1
#SBATCH -n ${NPROCS}
#SBATCH --mem=${MEMORY_GB}G
#SBATCH --time=48:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=${EMAIL}

module purge
module load gcc/13.3.0-xp3epyt openmpi/5.0.5 orca/6.0.1

# Create separate scratch directory for this job (better I/O)
SCRATCH_DIR=/tmp/\${SLURM_JOB_ID}_${job_name}
mkdir -p \${SCRATCH_DIR}
echo "Working directory: \${SCRATCH_DIR}"

# Copy input files to scratch
cp ${output_dir}/${input_file} \${SCRATCH_DIR}/
cp ${output_dir}/*.xyz \${SCRATCH_DIR}/ 2>/dev/null || true

# Change to scratch directory
cd \${SCRATCH_DIR}

# Run ORCA calculation
echo "Starting ORCA at \$(date)"
${ORCA_PATH} ${input_file} > ${input_file%.inp}.out

# Check if completed successfully
if grep -q "ORCA TERMINATED NORMALLY" ${input_file%.inp}.out; then
    echo "Calculation completed successfully at \$(date)"
else
    echo "WARNING: Calculation may have issues - check output"
fi

# Copy all results back to output directory
echo "Copying results back to ${output_dir}"
cp -r * ${output_dir}/

# Clean up scratch directory
cd ..
rm -rf \${SCRATCH_DIR}

echo "Job finished at \$(date)"
EOF
    
    chmod +x ${slurm_file}
}

# Generate optimization input files and SLURM scripts
echo ""
echo "Generating optimization files..."
echo ""

for system in "${SYSTEMS[@]}"; do
    echo "Processing ${system}..."
    
    # Check if xyz file exists
    if [ ! -f "${BASE_DIR}/xyz_files/${system}.xyz" ]; then
        echo "  ✗ ERROR: ${system}.xyz not found in xyz_files/"
        continue
    fi
    
    # Paths
    opt_dir="${BASE_DIR}/calculations/${system}/optimization/water"
    input_file="${system}_opt_water.inp"
    job_name="${system}_opt_water"
    slurm_file="${BASE_DIR}/job_scripts/${system}/${job_name}.sh"
    
    # Generate input file
    generate_opt_input ${system} ${opt_dir}/${input_file}
    echo "  ✓ Generated: ${input_file}"
    
    # Copy xyz file
    cp ${BASE_DIR}/xyz_files/${system}.xyz ${opt_dir}/
    
    # Generate SLURM script
    generate_slurm_script ${job_name} ${input_file} ${opt_dir} ${slurm_file}
    echo "  ✓ Generated: ${job_name}.sh"
done

echo ""
echo "============================================================================"
echo "Setup Complete!"
echo "============================================================================"
echo ""
echo "Generated files for ${#SYSTEMS[@]} systems:"
for system in "${SYSTEMS[@]}"; do
    echo "  - ${system}: Input file and SLURM script ready"
done

echo ""
echo "Next steps:"
echo "  1. Review an input file:"
echo "     cat calculations/AB113/optimization/water/AB113_opt_water.inp"
echo ""
echo "  2. Submit jobs:"
echo "     cd ${BASE_DIR}"
echo "     sbatch job_scripts/MRD/MRD_opt_water.sh"
echo "     sbatch job_scripts/A07/A07_opt_water.sh"
echo "     sbatch job_scripts/AB113/AB113_opt_water.sh"
echo "     sbatch job_scripts/SDIII/SDIII_opt_water.sh"
echo "     sbatch job_scripts/CRD/CRD_opt_water.sh"
echo ""
echo "  Or submit all at once:"
echo "     for script in job_scripts/*/\*_opt_water.sh; do sbatch \$script; done"
echo ""
echo "  3. Monitor jobs:"
echo "     squeue -u momoniyi"
echo ""
echo "============================================================================"