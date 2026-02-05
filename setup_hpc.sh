#!/bin/bash

# ORCA Workflow Deployment Script for UVM HPC
# Run this script on the HPC to set up your calculation environment

echo "============================================================================"
echo "ORCA Workflow Setup for /users/m/o/momoniyi/MM"
echo "============================================================================"

# Base directory
BASE_DIR="/users/m/o/momoniyi/MM"

echo ""
echo "Creating directory structure..."
mkdir -p ${BASE_DIR}/xyz_files
mkdir -p ${BASE_DIR}/calculations
mkdir -p ${BASE_DIR}/job_scripts
mkdir -p ${BASE_DIR}/analysis_results

echo "✓ Directories created"

# Copy xyz files if they exist in current directory
if ls *.xyz 1> /dev/null 2>&1; then
    echo ""
    echo "Found .xyz files in current directory, copying to ${BASE_DIR}/xyz_files..."
    cp *.xyz ${BASE_DIR}/xyz_files/
    echo "✓ XYZ files copied"
fi

# Check for xyz files
echo ""
echo "Checking for coordinate files..."
cd ${BASE_DIR}/xyz_files

required_files=("MRD.xyz" "A07.xyz" "AB113.xyz" "SDIII.xyz" "CRD.xyz")
all_found=true

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ Found: $file"
    else
        echo "  ✗ Missing: $file"
        all_found=false
    fi
done

echo ""
if [ "$all_found" = true ]; then
    echo "============================================================================"
    echo "✓ Setup complete! All files are ready."
    echo ""
    echo "Next steps:"
    echo "  1. cd ${BASE_DIR}"
    echo "  2. julia orca_complete_workflow.jl setup-only"
    echo "  3. julia orca_complete_workflow.jl opt-only"
    echo "============================================================================"
else
    echo "============================================================================"
    echo "⚠ Some .xyz files are missing!"
    echo ""
    echo "Please copy your coordinate files to: ${BASE_DIR}/xyz_files/"
    echo ""
    echo "Required files:"
    for file in "${required_files[@]}"; do
        echo "  - $file"
    done
    echo "============================================================================"
fi

echo ""
echo "Directory structure created:"
echo "  ${BASE_DIR}/"
echo "  ├── xyz_files/          (coordinate files)"
echo "  ├── calculations/        (will contain all outputs)"
echo "  ├── job_scripts/         (will contain SLURM scripts)"
echo "  └── analysis_results/    (will contain CSV summaries)"
echo ""
