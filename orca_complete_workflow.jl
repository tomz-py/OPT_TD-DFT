#!/usr/bin/env julia

"""
ORCA Computational Chemistry Workflow - Complete Automation Script
Performs geometry optimization and TD-DFT spectroscopic calculations on HPC

Author: Computational Chemistry Automation
"""

using Printf
using Dates

# ============================================================================
# CONFIGURATION - EDIT THESE SETTINGS FOR YOUR HPC
# ============================================================================

# HPC Cluster Settings
const ORCA_PATH = "/gpfs1/sw/rh9/pkgs/stacks/gcc/13.3.0/mpi-pkgs/openmpi/5.0.5/orca/6.0.1/orca"
const SLURM_PARTITION = "general"                # Your SLURM partition
const SLURM_ACCOUNT = ""                         # Optional: SLURM account name
const SLURM_TIME = "48:00:00"                    # Maximum walltime
const NPROCS = 48                                # Number of processors
const MEMORY_MB = 512000                         # Memory in MB (500GB = 512000 MB)
const EMAIL_ADDRESS = "Modupe.Omoniyi@uvm.edu"   # Email for job notifications

# Module loading
const MODULE_COMMANDS = """
module purge
module load gcc/13.3.0-xp3epyt openmpi/5.0.5 orca/6.0.1
"""

# System Configuration
const SYSTEMS = ["MRD", "A07", "AB113", "SDIII", "CRD"]
const ENVIRONMENTS = ["water"]                   # Water only as requested

# Calculation Settings
const OPT_FUNCTIONAL = "B3LYP"                   # Functional for optimization
const OPT_BASIS = "6-311G(d,p)"                  # Basis set for optimization
const OPT_AUX_BASIS = "def2/J"                   # Auxiliary basis
const SCF_MAXITER = 5000                         # SCF max iterations

# TD-DFT Settings
const TDDFT_METHODS = ["TDA", "TDDFT", "sTDA", "sTDDFT"]
const FUNCTIONALS = ["BP86", "B3LYP", "TPSSh", "M06", "CAM-B3LYP", "LC-BLYP", "wB97X"]
const N_EXCITED_STATES = 50                      # Number of excited states to calculate

# Directory Settings
const BASE_DIR = "/users/m/o/momoniyi/MM"        # Your base directory on HPC
const XYZ_DIR = joinpath(BASE_DIR, "xyz_files")  # XYZ files location
const WORK_DIR = joinpath(BASE_DIR, "calculations") # Main calculation directory
const SCRIPTS_DIR = joinpath(BASE_DIR, "job_scripts")
const RESULTS_DIR = joinpath(BASE_DIR, "analysis_results")

# ============================================================================
# INPUT FILE GENERATION
# ============================================================================

"""
Generate ORCA input file for geometry optimization following the provided format
"""
function generate_opt_input(system_name::String, xyz_file::String, environment::String)
    # Determine solvation model - use CPCM(Water) for water
    smd_keyword = environment == "water" ? "CPCM(Water)" : ""
    
    input = """## ORCA input file for $(system_name) optimization
# Generated: $(now())
# Environment: $(environment)
# 
! $(OPT_FUNCTIONAL) OPT FREQ $(OPT_BASIS) $(OPT_AUX_BASIS) D3BJ RIJCOSX PAL$(NPROCS)
$(smd_keyword != "" ? "! $smd_keyword" : "")

%maxcore $(div(MEMORY_MB, NPROCS))

%scf
\tMaxIter $(SCF_MAXITER)
\tCNVDIIS 1
\tCNVSOSCF 1
end

%geom
\tMaxIter 500
\tTolE 5e-6
\tTolRMSG 1e-4
\tTolMaxG 3e-4
end

%output
\tprint[p_mos] true
\tprint[p_basis] 5
end

*xyzfile 0 1 $(basename(xyz_file))
"""
    
    return input
end

"""
Generate ORCA input file for TD-DFT calculation
"""
function generate_tddft_input(system_name::String, xyz_file::String, 
                               method::String, functional::String, environment::String)
    # Determine solvation model - use CPCM(Water) for water
    smd_keyword = environment == "water" ? "CPCM(Water)" : ""
    
    # Handle special functional names
    orca_functional = functional == "wB97X" ? "wB97X-D3" : functional
    
    # Determine method-specific keywords
    tda_flag = (method == "TDA" || method == "sTDA") ? "TDA" : ""
    simplified_flag = (method == "sTDA" || method == "sTDDFT") ? "sTD" : ""
    
    input = """## ORCA input file for $(system_name) TD-DFT
# Generated: $(now())
# Method: $(method), Functional: $(functional)
# Environment: $(environment)
# 
! $(orca_functional) $(OPT_BASIS) $(OPT_AUX_BASIS) RIJCOSX PAL$(NPROCS)
$(smd_keyword != "" ? "! $smd_keyword" : "")
$(tda_flag != "" ? "! $tda_flag" : "")

%maxcore $(div(MEMORY_MB, NPROCS))

%scf
\tMaxIter $(SCF_MAXITER)
\tCNVDIIS 1
\tCNVSOSCF 1
end

%tddft
\tnroots $(N_EXCITED_STATES)
\tmaxdim 5
$(simplified_flag != "" ? "\t$(simplified_flag) true" : "")
end

%output
\tprint[p_mos] true
\tprint[p_basis] 5
end

*xyzfile 0 1 $(basename(xyz_file))
"""
    
    return input
end

# ============================================================================
# SLURM JOB SCRIPT GENERATION
# ============================================================================

"""
Generate SLURM job submission script matching user's format
Each job runs in its own scratch directory for better I/O
"""
function generate_slurm_script(job_name::String, input_file::String, output_dir::String)
    account_line = SLURM_ACCOUNT != "" ? "#SBATCH --account=$(SLURM_ACCOUNT)" : ""
    email_lines = EMAIL_ADDRESS != "" ? "#SBATCH --mail-type=ALL\n#SBATCH --mail-user=$(EMAIL_ADDRESS)" : ""
    
    script = """#!/bin/bash
#SBATCH --job-name=$(job_name)
#SBATCH -o $(job_name)_slurm.out
#SBATCH -e $(job_name)_slurm.err
#SBATCH --partition=$(SLURM_PARTITION)
$(account_line != "" ? account_line : "")
#SBATCH -N 1
#SBATCH -n $(NPROCS)
#SBATCH --mem=$(div(MEMORY_MB, 1024))G
#SBATCH --time=$(SLURM_TIME)
$(email_lines)

$(MODULE_COMMANDS)

# Create separate scratch directory for this job (better I/O)
SCRATCH_DIR=/tmp/\${SLURM_JOB_ID}_$(job_name)
mkdir -p \${SCRATCH_DIR}
echo "Working directory: \${SCRATCH_DIR}"

# Copy input files to scratch
cp $(output_dir)/$(input_file) \${SCRATCH_DIR}/
cp $(output_dir)/*.xyz \${SCRATCH_DIR}/ 2>/dev/null || true

# Change to scratch directory
cd \${SCRATCH_DIR}

# Run ORCA calculation
echo "Starting ORCA at \$(date)"
$(ORCA_PATH) $(input_file) > $(replace(input_file, ".inp" => ".out"))

# Check if completed successfully
if grep -q "ORCA TERMINATED NORMALLY" $(replace(input_file, ".inp" => ".out")); then
    echo "Calculation completed successfully at \$(date)"
else
    echo "WARNING: Calculation may have issues - check output"
fi

# Copy all results back to output directory
echo "Copying results back to $(output_dir)"
cp -r * $(output_dir)/

# Clean up scratch directory
cd ..
rm -rf \${SCRATCH_DIR}

echo "Job finished at \$(date)"
"""
    
    return script
end

# ============================================================================
# FILE MANAGEMENT
# ============================================================================

"""
Find XYZ file for a given system (case-insensitive)
"""
function find_xyz_file(system_name::String)
    if !isdir(XYZ_DIR)
        error("XYZ directory not found: $XYZ_DIR. Please create it and add your .xyz files.")
    end
    
    possible_names = [
        "$(system_name).xyz",
        lowercase("$(system_name).xyz"),
        uppercase("$(system_name).xyz")
    ]
    
    for name in possible_names
        filepath = joinpath(XYZ_DIR, name)
        if isfile(filepath)
            return filepath
        end
    end
    
    error("Could not find XYZ file for system: $system_name in $XYZ_DIR\nTried: $(join(possible_names, ", "))")
end

"""
Create directory structure for calculations
"""
function setup_directories(system_name::String)
    dirs = [
        joinpath(WORK_DIR, system_name, "optimization"),
        joinpath(WORK_DIR, system_name, "tddft"),
        joinpath(SCRIPTS_DIR, system_name)
    ]
    
    for env in ENVIRONMENTS
        push!(dirs, joinpath(WORK_DIR, system_name, "optimization", env))
        push!(dirs, joinpath(WORK_DIR, system_name, "tddft", env))
    end
    
    for dir in dirs
        mkpath(dir)
    end
end

# ============================================================================
# JOB SUBMISSION
# ============================================================================

"""
Submit a SLURM job and return job ID
"""
function submit_job(script_file::String)
    try
        result = read(`sbatch $script_file`, String)
        # Parse job ID from "Submitted batch job 12345"
        job_id = parse(Int, match(r"\d+$", result).match)
        return job_id
    catch e
        println("ERROR submitting job: $e")
        return nothing
    end
end

"""
Check if a job is still running
"""
function is_job_running(job_id::Int)
    try
        result = read(`squeue -j $job_id -h`, String)
        return !isempty(strip(result))
    catch
        return false
    end
end

# ============================================================================
# WORKFLOW PROCESSING
# ============================================================================

"""
Process geometry optimizations for all systems
"""
function process_optimizations()
    println("\n" * "="^80)
    println("GEOMETRY OPTIMIZATION WORKFLOW")
    println("="^80)
    
    all_jobs = Dict{String, Vector{Int}}()
    
    for system in SYSTEMS
        println("\n📁 Processing system: $system")
        
        try
            # Find XYZ file
            xyz_file = find_xyz_file(system)
            println("   Found XYZ file: $(basename(xyz_file))")
            
            # Setup directories
            setup_directories(system)
            
            job_ids = Int[]
            
            for env in ENVIRONMENTS
                println("\n   Environment: $env")
                
                # Paths
                opt_dir = joinpath(WORK_DIR, system, "optimization", env)
                input_filename = "$(system)_opt_$(env).inp"
                input_path = joinpath(opt_dir, input_filename)
                
                # Generate input file
                input_content = generate_opt_input(system, xyz_file, env)
                write(input_path, input_content)
                println("      ✓ Generated input: $input_filename")
                
                # Copy XYZ file
                cp(xyz_file, joinpath(opt_dir, basename(xyz_file)), force=true)
                
                # Generate SLURM script
                job_name = "$(system)_opt_$(env)"
                script_content = generate_slurm_script(job_name, input_filename, opt_dir)
                script_path = joinpath(SCRIPTS_DIR, system, "$(job_name).sh")
                write(script_path, script_content)
                chmod(script_path, 0o755)
                println("      ✓ Generated SLURM script: $(job_name).sh")
                
                # Submit job
                job_id = submit_job(script_path)
                if job_id !== nothing
                    push!(job_ids, job_id)
                    println("      ✓ Submitted job ID: $job_id")
                else
                    println("      ✗ Failed to submit job")
                end
            end
            
            all_jobs[system] = job_ids
            
        catch e
            println("   ✗ ERROR processing $system: $e")
            continue
        end
    end
    
    return all_jobs
end

"""
Process TD-DFT calculations for all systems
"""
function process_tddft(optimized_geometries::Dict{String, String})
    println("\n" * "="^80)
    println("TD-DFT SPECTROSCOPY WORKFLOW")
    println("="^80)
    
    all_jobs = Dict{String, Vector{Int}}()
    
    for system in SYSTEMS
        if !haskey(optimized_geometries, system)
            println("\n⚠️  Skipping $system - no optimized geometry available")
            continue
        end
        
        println("\n📁 Processing system: $system")
        opt_xyz = optimized_geometries[system]
        println("   Using optimized geometry: $(basename(opt_xyz))")
        
        job_ids = Int[]
        total_calcs = length(ENVIRONMENTS) * length(TDDFT_METHODS) * length(FUNCTIONALS)
        calc_count = 0
        
        for env in ENVIRONMENTS
            tddft_dir = joinpath(WORK_DIR, system, "tddft", env)
            
            for method in TDDFT_METHODS
                for functional in FUNCTIONALS
                    calc_count += 1
                    
                    # Paths
                    input_filename = "$(system)_$(method)_$(functional)_$(env).inp"
                    input_path = joinpath(tddft_dir, input_filename)
                    
                    # Generate input
                    input_content = generate_tddft_input(system, opt_xyz, method, functional, env)
                    write(input_path, input_content)
                    
                    # Copy geometry
                    cp(opt_xyz, joinpath(tddft_dir, basename(opt_xyz)), force=true)
                    
                    # Generate SLURM script
                    job_name = "$(system)_$(method)_$(functional)_$(env)"
                    script_content = generate_slurm_script(job_name, input_filename, tddft_dir)
                    script_path = joinpath(SCRIPTS_DIR, system, "$(job_name).sh")
                    write(script_path, script_content)
                    chmod(script_path, 0o755)
                    
                    # Submit job
                    job_id = submit_job(script_path)
                    if job_id !== nothing
                        push!(job_ids, job_id)
                    end
                end
            end
        end
        
        println("   ✓ Submitted $calc_count TD-DFT calculations ($(length(job_ids)) jobs)")
        all_jobs[system] = job_ids
    end
    
    return all_jobs
end

# ============================================================================
# RESULTS ANALYSIS
# ============================================================================

"""
Extract final energy from ORCA output
"""
function extract_final_energy(filename::String)
    if !isfile(filename)
        return nothing
    end
    
    lines = readlines(filename)
    for line in lines
        if occursin("FINAL SINGLE POINT ENERGY", line)
            parts = split(line)
            return parse(Float64, parts[end])
        end
    end
    return nothing
end

"""
Check if optimization converged
"""
function check_converged(filename::String)
    if !isfile(filename)
        return false
    end
    content = read(filename, String)
    return occursin("***        THE OPTIMIZATION HAS CONVERGED     ***", content) &&
           occursin("****ORCA TERMINATED NORMALLY****", content)
end

"""
Extract TD-DFT excitations
"""
function extract_excitations(filename::String)
    if !isfile(filename)
        return nothing
    end
    
    lines = readlines(filename)
    excitations = []
    
    in_spectrum = false
    for line in lines
        if occursin("ABSORPTION SPECTRUM VIA TRANSITION ELECTRIC DIPOLE MOMENTS", line)
            in_spectrum = true
            continue
        end
        
        if in_spectrum && occursin(r"^\s+\d+", line)
            parts = split(line)
            if length(parts) >= 4
                try
                    push!(excitations, (
                        state = parse(Int, parts[1]),
                        energy_ev = parse(Float64, parts[2]),
                        wavelength_nm = parse(Float64, parts[3]),
                        osc_strength = parse(Float64, parts[4])
                    ))
                catch
                    continue
                end
            end
        end
        
        if in_spectrum && occursin("---", line) && length(line) > 50
            break
        end
    end
    
    return excitations
end

"""
Generate analysis report
"""
function analyze_results()
    println("\n" * "="^80)
    println("RESULTS ANALYSIS")
    println("="^80)
    
    mkpath(RESULTS_DIR)
    
    # Optimization summary
    println("\n📊 Analyzing optimizations...")
    opt_summary = open(joinpath(RESULTS_DIR, "optimization_summary.txt"), "w")
    
    write(opt_summary, "Geometry Optimization Summary\n")
    write(opt_summary, "="^80 * "\n")
    write(opt_summary, "Generated: $(now())\n\n")
    
    for system in SYSTEMS
        write(opt_summary, "\nSystem: $system\n")
        write(opt_summary, "-"^80 * "\n")
        
        for env in ENVIRONMENTS
            opt_dir = joinpath(WORK_DIR, system, "optimization", env)
            out_file = joinpath(opt_dir, "$(system)_opt_$(env).out")
            
            if isfile(out_file)
                energy = extract_final_energy(out_file)
                converged = check_converged(out_file)
                
                write(opt_summary, "  $env:\n")
                write(opt_summary, "    Converged: $(converged ? "✓" : "✗")\n")
                if energy !== nothing
                    write(opt_summary, "    Final Energy: $(@sprintf("%.8f", energy)) Eh\n")
                end
            else
                write(opt_summary, "  $env: No output file found\n")
            end
        end
    end
    
    close(opt_summary)
    println("   ✓ Saved: optimization_summary.txt")
    
    # TD-DFT summary
    println("\n📊 Analyzing TD-DFT calculations...")
    tddft_summary = open(joinpath(RESULTS_DIR, "tddft_summary.csv"), "w")
    
    write(tddft_summary, "System,Environment,Method,Functional,State,Energy_eV,Wavelength_nm,OscStrength\n")
    
    excitation_count = 0
    for system in SYSTEMS
        for env in ENVIRONMENTS
            tddft_dir = joinpath(WORK_DIR, system, "tddft", env)
            if !isdir(tddft_dir)
                continue
            end
            
            for method in TDDFT_METHODS
                for functional in FUNCTIONALS
                    out_file = joinpath(tddft_dir, "$(system)_$(method)_$(functional)_$(env).out")
                    
                    excitations = extract_excitations(out_file)
                    if excitations !== nothing
                        for exc in excitations
                            write(tddft_summary, "$(system),$(env),$(method),$(functional),")
                            write(tddft_summary, "$(exc.state),$(exc.energy_ev),")
                            write(tddft_summary, "$(exc.wavelength_nm),$(exc.osc_strength)\n")
                            excitation_count += 1
                        end
                    end
                end
            end
        end
    end
    
    close(tddft_summary)
    println("   ✓ Saved: tddft_summary.csv ($excitation_count excitations)")
    
    println("\n" * "="^80)
    println("Analysis complete! Results saved in: $RESULTS_DIR")
    println("="^80)
end

# ============================================================================
# MONITORING
# ============================================================================

"""
Monitor job status
"""
function monitor_jobs(job_dict::Dict{String, Vector{Int}})
    println("\n" * "="^80)
    println("JOB MONITORING")
    println("="^80)
    
    total_jobs = sum(length(jobs) for jobs in values(job_dict))
    println("Total jobs submitted: $total_jobs")
    println("\nChecking SLURM queue...\n")
    
    try
        user = strip(read(`whoami`, String))
        result = read(`squeue -u $user -o "%.18i %.9P %.30j %.8T %.10M"`, String)
        println(result)
    catch e
        println("Unable to check queue: $e")
    end
    
    println("\nTo monitor jobs:")
    println("  squeue -u \$USER")
    println("  tail -f $(WORK_DIR)/SYSTEM/*/ENV/*.out")
    println("="^80)
end

# ============================================================================
# MAIN WORKFLOW
# ============================================================================

"""
Main execution function with options
"""
function run_workflow(mode::String="opt-only")
    println("\n" * "="^80)
    println("ORCA COMPUTATIONAL CHEMISTRY WORKFLOW")
    println("="^80)
    println("Start time: $(now())")
    println("Mode: $mode")
    println("\nSystems: $(join(SYSTEMS, ", "))")
    println("Environments: $(join(ENVIRONMENTS, ", "))")
    println("="^80)
    
    # Create main directories
    mkpath(XYZ_DIR)
    mkpath(WORK_DIR)
    mkpath(SCRIPTS_DIR)
    mkpath(RESULTS_DIR)
    
    if mode == "setup-only"
        println("\n📋 SETUP MODE - Creating directories and checking files...")
        
        for system in SYSTEMS
            try
                xyz_file = find_xyz_file(system)
                setup_directories(system)
                println("✓ $system: Ready (found $(basename(xyz_file)))")
            catch e
                println("✗ $system: $e")
            end
        end
        
        println("\nSetup complete. Run with mode='opt-only' to submit optimization jobs.")
        return
    end
    
    # Run optimizations
    if mode == "opt-only" || mode == "full"
        opt_jobs = process_optimizations()
        monitor_jobs(opt_jobs)
        
        if mode == "opt-only"
            println("\n✓ Optimization jobs submitted!")
            println("After jobs complete, run analyze_results() or use mode='tddft-only'")
            return opt_jobs
        end
    end
    
    # Wait for optimizations if full mode
    if mode == "full"
        println("\n⏳ Waiting for optimizations to complete...")
        # In practice, you'd wait here or check manually
        println("⚠️  Full automatic mode requires manual checking")
        println("   Run with mode='tddft-only' after optimizations complete")
        return
    end
    
    # Run TD-DFT
    if mode == "tddft-only"
        println("\n📋 Finding optimized geometries...")
        opt_geoms = Dict{String, String}()
        
        for system in SYSTEMS
            for env in ENVIRONMENTS
                opt_dir = joinpath(WORK_DIR, system, "optimization", env)
                xyz_file = joinpath(opt_dir, "$(system)_opt_$(env).xyz")
                
                if isfile(xyz_file)
                    opt_geoms[system] = xyz_file
                    println("   ✓ Found: $system → $(basename(xyz_file))")
                    break
                end
            end
            
            # Fallback to original xyz if optimization not found
            if !haskey(opt_geoms, system)
                try
                    xyz_file = find_xyz_file(system)
                    opt_geoms[system] = xyz_file
                    println("   ⚠️  $system: Using original geometry (optimization not found)")
                catch e
                    println("   ✗ $system: No geometry available")
                end
            end
        end
        
        if !isempty(opt_geoms)
            tddft_jobs = process_tddft(opt_geoms)
            monitor_jobs(tddft_jobs)
            println("\n✓ TD-DFT jobs submitted!")
            return tddft_jobs
        else
            println("✗ No geometries available for TD-DFT calculations")
            return nothing
        end
    end
    
    # Analyze results
    if mode == "analyze"
        analyze_results()
        return
    end
end

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

function show_help()
    println("""
    ORCA Computational Chemistry Workflow
    
    Usage: julia $(basename(@__FILE__)) [MODE]
    
    Modes:
      setup-only   - Check files and create directory structure (no job submission)
      opt-only     - Submit geometry optimization jobs only (default)
      tddft-only   - Submit TD-DFT jobs (requires completed optimizations)
      full         - Submit all jobs with monitoring
      analyze      - Analyze completed results
      help         - Show this help message
    
    Examples:
      julia $(basename(@__FILE__))              # Submit optimizations
      julia $(basename(@__FILE__)) setup-only   # Check setup
      julia $(basename(@__FILE__)) analyze      # Analyze results
    
    Configuration:
      Edit the CONFIGURATION section at the top of this file:
      - ORCA_PATH: Path to ORCA executable
      - SLURM_PARTITION: Your HPC partition name  
      - NPROCS: Number of processors
      - MODULE_COMMANDS: Modules to load
      - SYSTEMS: List of systems to calculate
      
    Directory Structure:
      xyz_files/           - Place your .xyz files here
      orca_calculations/   - All calculation outputs
      job_scripts/         - SLURM submission scripts
      analysis_results/    - Analysis summaries
    
    For detailed documentation, see the script comments.
    """)
end

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if abspath(PROGRAM_FILE) == @__FILE__
    mode = length(ARGS) > 0 ? ARGS[1] : "opt-only"
    
    if mode == "help" || mode == "--help" || mode == "-h"
        show_help()
    elseif mode in ["setup-only", "opt-only", "tddft-only", "full", "analyze"]
        run_workflow(mode)
    else
        println("Unknown mode: $mode")
        println("Run with 'help' for usage information")
    end
end
