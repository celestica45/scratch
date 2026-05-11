configfile: "config/config.yaml"


def as_bool(value):
    if isinstance(value, bool):
        return value

    if isinstance(value, str):
        return value.lower() in ["true", "yes", "1", "on"]

    return bool(value)


ANTIBIOTICS = config["antibiotics"]
RAW_DATA_DIR = config.get("raw_data_dir", "resources/raw_data")
RESULTS_DIR = config.get("results_dir", "results")
RUN_QUAST = as_bool(config.get("run_quast", False))
QUAST_CONFIG = config.get("quast", {})
QUAST_REFERENCE = QUAST_CONFIG["reference"]
QUAST_ANNOTATION = QUAST_CONFIG["annotation"]


METADATA_TARGETS = expand(
    [
        f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_amr_metadata.csv",
        f"{RESULTS_DIR}/{{antibiotic}}/metadata/sample_assembly_map.txt",
        f"{RESULTS_DIR}/{{antibiotic}}/metadata/assembly_ids.txt",
        f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_preprocess_summary.txt",
    ],
    antibiotic=ANTIBIOTICS,
)

ASSEMBLY_TARGETS = expand(
    [
        f"{RESULTS_DIR}/{{antibiotic}}/assemblies/download_summary.txt",
        f"{RESULTS_DIR}/{{antibiotic}}/assemblies/assembly_download_manifest.tsv",
    ],
    antibiotic=ANTIBIOTICS,
)

QUAST_TARGETS = expand(
    f"{RESULTS_DIR}/{{antibiotic}}/qc/quast/report.html",
    antibiotic=ANTIBIOTICS,
) if RUN_QUAST else []

FINAL_TARGETS = METADATA_TARGETS + ASSEMBLY_TARGETS + QUAST_TARGETS

rule all:
    input:
        FINAL_TARGETS

rule preprocess_raw_data:
    input:
        lambda wildcards: f"{RAW_DATA_DIR}/{wildcards.antibiotic}_amr.csv"
    output:
        cleaned_csv=f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_amr_metadata.csv",
        sample_assembly_map=f"{RESULTS_DIR}/{{antibiotic}}/metadata/sample_assembly_map.txt",
        assembly_ids=f"{RESULTS_DIR}/{{antibiotic}}/metadata/assembly_ids.txt",
        summary_txt=f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_preprocess_summary.txt"
    conda:
        "envs/preprocess.yaml"
    params:
        output_dir=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/metadata"
    shell:
        """
        python scripts/preprocess_raw_data.py \
            --input-csv {input} \
            --antibiotic {wildcards.antibiotic} \
            --output-dir {params.output_dir}
        """

rule download_assemblies:
    input:
        assembly_ids=f"{RESULTS_DIR}/{{antibiotic}}/metadata/assembly_ids.txt"
    output:
        summary=f"{RESULTS_DIR}/{{antibiotic}}/assemblies/download_summary.txt",
        manifest=f"{RESULTS_DIR}/{{antibiotic}}/assemblies/assembly_download_manifest.tsv"
    conda:
        "envs/download_assemblies.yaml"
    params:
        output_dir=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/assemblies",
        retries=3,
        batch_size=25
    shell:
        """
        python scripts/download_assemblies.py \
            --assembly-ids {input.assembly_ids} \
            --output-dir {params.output_dir} \
            --retries {params.retries} \
            --batch-size {params.batch_size}
        """

rule run_quast:
    input:
        manifest=f"{RESULTS_DIR}/{{antibiotic}}/assemblies/assembly_download_manifest.tsv",
        reference=QUAST_REFERENCE,
        annotation=QUAST_ANNOTATION
    output:
        report=f"{RESULTS_DIR}/{{antibiotic}}/qc/quast/report.html"
    conda:
        "envs/quast.yaml"
    threads: 4
    params:
        assemblies_dir=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/assemblies",
        output_dir=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/qc/quast"
    shell:
        """
        quast.py {params.assemblies_dir}/*.fa \
            --threads {threads} \
            --output-dir {params.output_dir} \
            --reference {input.reference} \
            --features {input.annotation}
        """
