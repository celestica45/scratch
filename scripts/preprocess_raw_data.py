import argparse
import math
import re
from pathlib import Path

import numpy as np
import pandas as pd


# ============================================================
# SETTINGS
# Change these only when you use another antibiotic/input file
# ============================================================

parser = argparse.ArgumentParser(description="Preprocess raw AMR phenotype CSV data.")
parser.add_argument("--input-csv", required=True, help="Raw antibiotic CSV to preprocess.")
parser.add_argument("--antibiotic", required=True, help="Antibiotic name.")
parser.add_argument("--output-dir", required=True, help="Directory for preprocessing outputs.")
args = parser.parse_args()

input_csv = args.input_csv
antibiotic = args.antibiotic
output_dir = Path(args.output_dir)
output_dir.mkdir(parents=True, exist_ok=True)

cleaned_csv = output_dir / f"{antibiotic}_amr_metadata.csv"
sample_assembly_map = output_dir / f"{antibiotic}_sample_assembly_map.txt"
assembly_ids = output_dir / f"{antibiotic}_assembly_ids.txt"
summary_txt = output_dir / f"{antibiotic}_preprocess_summary.txt"


# ============================================================
# FUNCTION: Convert MIC to transformed log2 MIC
# ============================================================

def convert_mic_to_log2(mic):
    """
    Converts MIC values to transformed log2 MIC.

    Examples:
    4 mg/L       -> log2(4)
    > 4 mg/L     -> log2(4) + 1
    >= 4 mg/L    -> log2(4) + 1
    < 0.5 mg/L   -> log2(0.5) - 1
    <= 0.5 mg/L  -> log2(0.5) - 1
    """

    if pd.isna(mic):
        return np.nan

    mic = str(mic).strip()

    pattern = r"^(<=|>=|<|>|=|==)?\s*([0-9]*\.?[0-9]+)\s*mg/L$"
    match = re.match(pattern, mic, re.IGNORECASE)

    if match is None:
        return np.nan

    operator = match.group(1)
    value = float(match.group(2))

    if value <= 0:
        return np.nan

    log2_value = math.log2(value)

    if operator == ">":
        return log2_value + 1

    if operator == "<":
        return log2_value - 1

    return log2_value


# ============================================================
# READ INPUT CSV
# ============================================================

df = pd.read_csv(input_csv)

original_rows = len(df)
original_columns = len(df.columns)

print(f"Original rows: {original_rows}")
print(f"Original columns: {original_columns}")


# ============================================================
# CLEAN COLUMN NAMES
# Remove "phenotype-" prefix from column names
# ============================================================

df.columns = df.columns.str.replace("phenotype-", "", regex=False)


# ============================================================
# CHECK REQUIRED COLUMNS
# ============================================================

if "assembly_ID" not in df.columns:
    raise ValueError("Missing required column: assembly_ID")

if "gen_measurement" not in df.columns:
    raise ValueError("Missing required column: gen_measurement")


# ============================================================
# DROP ROWS WITH MISSING assembly_ID
# ============================================================

missing_assembly = df["assembly_ID"].isna().sum()
df = df.dropna(subset=["assembly_ID"])


# ============================================================
# DROP ROWS WITH MISSING gen_measurement
# ============================================================

missing_gen_measurement = df["gen_measurement"].isna().sum()
df = df.dropna(subset=["gen_measurement"])


# ============================================================
# KEEP ONLY MIC MEASUREMENTS ENDING IN mg/L
# ============================================================

is_mg_l = df["gen_measurement"].astype(str).str.strip().str.endswith("mg/L")

not_mg_l = (~is_mg_l).sum()

df = df[is_mg_l].copy()


# ============================================================
# CONVERT MIC TO TRANSFORMED LOG2 MIC
# ============================================================

df["transformed_mic"] = df["gen_measurement"].apply(convert_mic_to_log2)

unparsed_mic = df["transformed_mic"].isna().sum()

df = df.dropna(subset=["transformed_mic"])


# ============================================================
# MOVE transformed_mic BESIDE gen_measurement
# ============================================================

columns = list(df.columns)

columns.remove("transformed_mic")

gen_measurement_position = columns.index("gen_measurement")

columns.insert(gen_measurement_position + 1, "transformed_mic")

df = df[columns]


# ============================================================
# SAVE CLEANED CSV
# ============================================================

df.to_csv(cleaned_csv, index=False)


# ============================================================
# SAVE sample_assembly_map.txt
#
# Format:
# assembly_ID    assembly_ID.fa
# ============================================================

map_df = pd.DataFrame()

map_df["assembly_ID"] = df["assembly_ID"]
map_df["file"] = df["assembly_ID"].astype(str) + ".fa"

map_df.to_csv(
    sample_assembly_map,
    sep="\t",
    index=False,
    header=False
)


# ============================================================
# SAVE assembly_ids.txt
# ============================================================

df["assembly_ID"].drop_duplicates().sort_values().to_csv(
    assembly_ids,
    index=False,
    header=False
)


# ============================================================
# CREATE SUMMARY VALUES
# ============================================================

final_rows = len(df)
total_dropped = original_rows - final_rows
unique_assemblies = df["assembly_ID"].nunique()


# ============================================================
# SAVE SUMMARY TXT FILE
# ============================================================

with open(summary_txt, "w", encoding="utf-8") as file:
    file.write("AMR PREPROCESSING SUMMARY\n")
    file.write("=========================\n\n")

    file.write(f"Input file: {input_csv}\n")
    file.write(f"Antibiotic: {antibiotic}\n\n")

    file.write(f"Original rows: {original_rows}\n")
    file.write(f"Original columns: {original_columns}\n")
    file.write(f"Final cleaned rows: {final_rows}\n")
    file.write(f"Unique assembly_ID values: {unique_assemblies}\n")
    file.write(f"Total dropped rows: {total_dropped}\n\n")

    file.write("Dropped rows by reason:\n")
    file.write("-----------------------\n")
    file.write(f"Missing assembly_ID: {missing_assembly}\n")
    file.write(f"Missing gen_measurement: {missing_gen_measurement}\n")
    file.write(f"gen_measurement not ending in mg/L: {not_mg_l}\n")
    file.write(f"MIC value could not be parsed/transformed: {unparsed_mic}\n\n")

    file.write("Output files:\n")
    file.write("-------------\n")
    file.write(f"Cleaned CSV: {cleaned_csv}\n")
    file.write(f"Sample assembly map: {sample_assembly_map}\n")
    file.write(f"Assembly IDs: {assembly_ids}\n")
    file.write(f"Summary TXT: {summary_txt}\n")


# ============================================================
# DONE
# ============================================================

print(f"Cleaned CSV saved as: {cleaned_csv}")
print(f"Sample assembly map saved as: {sample_assembly_map}")
print(f"Assembly IDs saved as: {assembly_ids}")
print(f"Summary saved as: {summary_txt}")
