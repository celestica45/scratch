import argparse
import shutil
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path


# ============================================================
# SETTINGS
# ============================================================

parser = argparse.ArgumentParser(description="Download NCBI assemblies from assembly IDs.")
parser.add_argument("--assembly-ids", required=True, help="Text file with one assembly ID per line.")
parser.add_argument("--output-dir", required=True, help="Directory for final FASTA assemblies.")
parser.add_argument("--antibiotic", required=True, help="Antibiotic name used in output filenames.")
parser.add_argument("--retries", type=int, default=3, help="Number of times to retry failed downloads.")
parser.add_argument("--batch-size", type=int, default=25, help="Number of assembly IDs per download batch.")
args = parser.parse_args()

assembly_ids_txt = Path(args.assembly_ids)
output_dir = Path(args.output_dir)
antibiotic = args.antibiotic
retries = max(1, args.retries)
batch_size = max(1, args.batch_size)

output_dir.mkdir(parents=True, exist_ok=True)

manifest_tsv = output_dir / f"{antibiotic}_assembly_download_manifest.tsv"
summary_txt = output_dir / f"{antibiotic}_download_summary.txt"


# ============================================================
# READ ASSEMBLY IDS
# ============================================================

assembly_ids = []
seen_assembly_ids = set()

with open(assembly_ids_txt, "r", encoding="utf-8") as file:
    for line in file:
        assembly_id = line.strip()

        if assembly_id == "":
            continue

        if assembly_id in seen_assembly_ids:
            continue

        assembly_ids.append(assembly_id)
        seen_assembly_ids.add(assembly_id)

if len(assembly_ids) == 0:
    raise ValueError(f"No assembly IDs found in: {assembly_ids_txt}")


# ============================================================
# FUNCTION: Split list into batches
# ============================================================

def split_into_batches(items, size):
    """
    Splits a list into smaller lists.

    Example:
    281 assembly IDs with size 25 becomes 12 batches.
    """

    batches = []

    for start in range(0, len(items), size):
        end = start + size
        batches.append(items[start:end])

    return batches


# ============================================================
# FUNCTION: Run command with retries
# ============================================================

def run_command_with_retries(command, max_attempts):
    """
    Runs a shell command. If it fails, try again until max_attempts is reached.
    """

    last_error = None

    for attempt in range(1, max_attempts + 1):
        print(f"Attempt {attempt} of {max_attempts}")
        print(" ".join(str(part) for part in command))

        result = subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
        )

        if result.returncode == 0:
            print(result.stdout)
            return

        last_error = result
        print(result.stdout)
        print(result.stderr)

        if attempt < max_attempts:
            time.sleep(5)

    raise RuntimeError(
        "Command failed after retries:\n"
        + " ".join(str(part) for part in command)
        + "\n\nSTDOUT:\n"
        + last_error.stdout
        + "\nSTDERR:\n"
        + last_error.stderr
    )


# ============================================================
# FUNCTION: Find downloaded FASTA files
# ============================================================

def find_downloaded_fasta_files(extracted_dir):
    """
    Finds FASTA files inside an extracted NCBI datasets package.
    """

    fasta_files = []
    fasta_extensions = [".fa", ".fna", ".fasta"]

    for path in extracted_dir.rglob("*"):
        if not path.is_file():
            continue

        if path.suffix.lower() in fasta_extensions:
            fasta_files.append(path)

    return fasta_files


# ============================================================
# FUNCTION: Match FASTA files to assembly IDs
# ============================================================

def match_fasta_files_to_assembly_ids(fasta_files, wanted_assembly_ids):
    """
    Matches each assembly ID to a FASTA file.

    NCBI datasets usually stores each genome under a folder named with
    the accession, such as ncbi_dataset/data/GCA_003193705.1/.
    """

    matched_fastas = {}

    for fasta_file in fasta_files:
        path_parts = fasta_file.parts

        for assembly_id in wanted_assembly_ids:
            if assembly_id in path_parts:
                matched_fastas[assembly_id] = fasta_file
                break

    return matched_fastas


# ============================================================
# DOWNLOAD ASSEMBLIES IN BATCHES
# ============================================================

batches = split_into_batches(assembly_ids, batch_size)
manifest_rows = []
missing_assembly_ids = []

with tempfile.TemporaryDirectory() as temp_dir_name:
    temp_dir = Path(temp_dir_name)

    for batch_number, batch_assembly_ids in enumerate(batches, start=1):
        batch_dir = temp_dir / f"batch_{batch_number:03d}"
        temporary_zip = batch_dir / "assemblies.zip"
        extracted_dir = batch_dir / "extracted"
        temporary_ids_txt = batch_dir / "assembly_ids.txt"

        batch_dir.mkdir(parents=True, exist_ok=True)

        with open(temporary_ids_txt, "w", encoding="utf-8") as file:
            for assembly_id in batch_assembly_ids:
                file.write(f"{assembly_id}\n")

        # ============================================================
        # DOWNLOAD NCBI DATASET PACKAGE
        # ============================================================

        print(f"Downloading batch {batch_number} of {len(batches)}")

        download_command = [
            "datasets",
            "download",
            "genome",
            "accession",
            "--inputfile",
            temporary_ids_txt,
            "--include",
            "genome",
            "--filename",
            temporary_zip,
        ]

        run_command_with_retries(download_command, retries)


        # ============================================================
        # EXTRACT FASTA FILES
        # ============================================================

        extracted_dir.mkdir(parents=True, exist_ok=True)

        with zipfile.ZipFile(temporary_zip, "r") as zip_file:
            zip_file.extractall(extracted_dir)

        fasta_files = find_downloaded_fasta_files(extracted_dir)
        matched_fastas = match_fasta_files_to_assembly_ids(fasta_files, batch_assembly_ids)

        # ============================================================
        # RENAME FASTA FILES
        # ============================================================

        for assembly_id in batch_assembly_ids:
            final_fasta = output_dir / f"{assembly_id}.fa"

            if assembly_id not in matched_fastas:
                missing_assembly_ids.append(assembly_id)
                manifest_rows.append([assembly_id, final_fasta.name, str(batch_number), "missing"])
                continue

            shutil.copyfile(matched_fastas[assembly_id], final_fasta)
            manifest_rows.append([assembly_id, final_fasta.name, str(batch_number), "downloaded"])


# ============================================================
# WRITE MANIFEST
# ============================================================

with open(manifest_tsv, "w", encoding="utf-8") as file:
    file.write("assembly_ID\tfasta_file\tbatch\tstatus\n")

    for row in manifest_rows:
        file.write("\t".join(row) + "\n")


# ============================================================
# WRITE SUMMARY
# ============================================================

downloaded_count = len([row for row in manifest_rows if row[3] == "downloaded"])
missing_count = len(missing_assembly_ids)

with open(summary_txt, "w", encoding="utf-8") as file:
    file.write("ASSEMBLY DOWNLOAD SUMMARY\n")
    file.write("=========================\n\n")

    file.write(f"Assembly IDs file: {assembly_ids_txt}\n")
    file.write(f"Output directory: {output_dir}\n\n")

    file.write(f"Batch size: {batch_size}\n")
    file.write(f"Total batches: {len(batches)}\n")
    file.write(f"Requested assemblies: {len(assembly_ids)}\n")
    file.write(f"Downloaded assemblies: {downloaded_count}\n")
    file.write(f"Missing assemblies: {missing_count}\n")
    file.write(f"Retries per batch: {retries}\n\n")

    file.write("Output files:\n")
    file.write("-------------\n")
    file.write(f"Manifest TSV: {manifest_tsv}\n")
    file.write(f"Summary TXT: {summary_txt}\n\n")

    if missing_count > 0:
        file.write("Missing assembly IDs:\n")
        file.write("---------------------\n")

        for assembly_id in missing_assembly_ids:
            file.write(f"{assembly_id}\n")


# ============================================================
# CHECK FOR FAILED DOWNLOADS
# ============================================================

if missing_count > 0:
    raise RuntimeError(
        f"{missing_count} assemblies were missing after download. "
        f"See {manifest_tsv} and {summary_txt}."
    )


# ============================================================
# DONE
# ============================================================

#print("Assembly download complete!")
print(f"Downloaded assemblies: {downloaded_count}")
print(f"Manifest saved as: {manifest_tsv}")
print(f"Summary saved as: {summary_txt}")
