#!/usr/bin/env python3
"""
update_registry.py - R14 registry updates
1. Add ledger_inputs column
2. Fix 12 paths missing data/ prefix
3. Restage S46/S47
4. Stage article/ rows
"""
import csv
import sys

REGISTRY = "meta/FILE_REGISTRY.csv"

# Task 1: Paths to fix (add data/ prefix)
PATH_FIXES = {
    # S34/S35 chain: S1R_ppml.rds -> data/S1R_ppml.rds
    "code/S34_a2_normality.R": ("S1R_ppml.rds", "data/S1R_ppml.rds"),
    "code/S35_jensen_control.R": ("S1R_ppml.rds", "data/S1R_ppml.rds"),
    "output/T38_a2_normality.csv": ("S1R_ppml.rds", "data/S1R_ppml.rds"),
    "output/T39_a2_jensen_identity.csv": ("S1R_ppml.rds", "data/S1R_ppml.rds"),
    "output/T40_jensen_control.csv": ("S1R_ppml.rds", "data/S1R_ppml.rds"),
    "output/F5_a2_normality_qq.pdf": ("S1R_ppml.rds", "data/S1R_ppml.rds"),
    # S46/S47 chain: ITPDE_total.rds -> data/ITPDE_total.rds
    "code/S46_ge_twodyad.R": ("ITPDE_total.rds", "data/ITPDE_total.rds"),
    "data/S46_ge_twodyad.rds": ("ITPDE_total.rds", "data/ITPDE_total.rds"),
    "output/T42_ge_twodyad.csv": ("ITPDE_total.rds", "data/ITPDE_total.rds"),
    "code/S47_ge_gradient.R": ("ITPDE_total.rds", "data/ITPDE_total.rds"),
    "data/S47_ge_gradient.rds": ("ITPDE_total.rds", "data/ITPDE_total.rds"),
    "output/T43_ge_gradient.csv": ("ITPDE_total.rds", "data/ITPDE_total.rds"),
}

# Task 2: Ledger inputs for scripts that read canonical_facts.md
LEDGER_INPUTS = {
    "code/S23_ge_bracket.R": "MEAN_THETA_D;SD_THETA_TRUE",
    "code/S30_moment_power.R": "ESIGMA2;VAR_SIGMA2",
    "code/S42_a2_constants.R": "MOMPOW_IDENT_MIN_Z;MOMPOW_IDENT_MAX_Z;A2_EXKURT;A2_EXKURT_CONTROL;HOLDOUT_D3_MEAN;HOLDOUT_D3_N;HOLDOUT_MAX_ABS_EX_D3",
    "code/S45_ledger_constants.R": "MEAN_THETA_D;SD_THETA_TRUE;GRADIENT;GRADIENT_B;GRADIENT_Q1;GRADIENT_Q5;GRADIENT_B_SHARE;PLACEBO_A_R;ESIGMA2",
    "code/S46_ge_twodyad.R": "SD_THETA_TRUE",
    "code/S47_ge_gradient.R": "GRADIENT_Q1;GRADIENT_Q5;SD_THETA_TRUE",
}

# Task 3: Restage GE chain
# S46: 8 -> 13 (after SD_THETA_TRUE producer S24_arms_canonical at stage 12)
# S47: 8 -> 14 (after GRADIENT_Q1/Q5 producer S28_gradient_B at stage 13)
RESTAGE = {
    "code/S46_ge_twodyad.R": "13",
    "data/S46_ge_twodyad.rds": "13",
    "output/T42_ge_twodyad.csv": "13",
    "meta/T42_ge_twodyad.csv.sidecar": "13",
    "meta/S46_ge_twodyad.rds.sidecar": "13",
    "code/S47_ge_gradient.R": "14",
    "data/S47_ge_gradient.rds": "14",
    "output/T43_ge_gradient.csv": "14",
    "meta/T43_ge_gradient.csv.sidecar": "14",
    "meta/S47_ge_gradient.rds.sidecar": "14",
}

# Task 4: Stage article/ rows (after S45 at stage 16)
ARTICLE_STAGE = "17"

def main():
    rows = []
    with open(REGISTRY, 'r', newline='') as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames)

        # Add ledger_inputs after inputs
        if 'ledger_inputs' not in fieldnames:
            idx = fieldnames.index('inputs') + 1
            fieldnames.insert(idx, 'ledger_inputs')

        for row in reader:
            fp = row['file_path']

            # Task 1: Fix paths
            if fp in PATH_FIXES:
                old, new = PATH_FIXES[fp]
                if row['inputs']:
                    row['inputs'] = row['inputs'].replace(old, new)

            # Task 2: Add ledger_inputs
            row['ledger_inputs'] = LEDGER_INPUTS.get(fp, '')

            # Task 3: Restage
            if fp in RESTAGE:
                row['stage'] = RESTAGE[fp]

            # Task 4: Stage article/ rows
            if fp.startswith('article/') and not row['stage']:
                row['stage'] = ARTICLE_STAGE

            rows.append(row)

    # Write back
    with open(REGISTRY, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Updated {len(rows)} rows")
    print(f"Columns: {fieldnames}")

    # Report changes
    print("\n=== Path fixes applied ===")
    for fp, (old, new) in PATH_FIXES.items():
        print(f"  {fp}: {old} -> {new}")

    print("\n=== Ledger inputs added ===")
    for fp, ids in LEDGER_INPUTS.items():
        print(f"  {fp}: {ids}")

    print("\n=== Restaged ===")
    for fp, stage in RESTAGE.items():
        print(f"  {fp}: -> stage {stage}")

if __name__ == "__main__":
    main()
