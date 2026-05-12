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
RUN_PANAROO_QC = as_bool(config.get("run_panaroo_qc", False))
PANAROO_QC_GRAPH_TYPE = config.get("panaroo_qc_graph_type", "all")
PANAROO_QC_THREADS = config.get("panaroo_qc_threads", 4)
RUN_PANAROO_PANGENOME = as_bool(config.get("run_panaroo_pangenome", False))
PANAROO_CLEAN_MODE = config.get("panaroo_clean_mode", "strict")
PANAROO_ALIGNMENT = config.get("panaroo_alignment", "core")
PANAROO_THREADS = config.get("panaroo_threads", 4)
RUN_KMERS = as_bool(config.get("run_kmers", False))
KMER_MIN = config.get("kmer_min", 1)
KMER_MAX = config.get("kmer_max", 10)

# Master switch for building all files needed before association testing.
# When false, rule all will not request preprocessing/input targets.
BUILD_ANALYSIS_INPUTS = as_bool(config.get("build_analysis_inputs", False))

# Master switch for running actual association/GWAS tests.
# Association test targets will be added in a later step.
RUN_ASSOCIATION_TESTS = as_bool(config.get("run_association_tests", False))

# Association-specific settings.
ASSOCIATION_CONFIG = config.get("association", {})

# Metadata column exported into {antibiotic}_phenotype.tsv.
# The output filename stays generic even if this column changes.
ASSOCIATION_PHENOTYPE_COLUMN = ASSOCIATION_CONFIG.get("phenotype_column", "transformed_mic")

# Mash sketch size for tutorial-style mash distance correction.
ASSOCIATION_MASH_SKETCH_SIZE = ASSOCIATION_CONFIG.get("mash_sketch_size", 10000)

# Fixed-effect config controls distance matrices used by regular pyseer via --distances.
ASSOCIATION_FIXED_CONFIG = ASSOCIATION_CONFIG.get("fixed_effects", {})

# LMM config controls kinship/similarity matrices used by pyseer --lmm via --similarity.
ASSOCIATION_LMM_CONFIG = ASSOCIATION_CONFIG.get("lmm", {})

# Enables/disables all fixed-effect population-structure inputs.
BUILD_FIXED_EFFECT_INPUTS = as_bool(ASSOCIATION_FIXED_CONFIG.get("enabled", False))

# Builds mash distance matrix: {antibiotic}_mash_fixed.tsv.
BUILD_FIXED_MASH_INPUTS = (
    BUILD_FIXED_EFFECT_INPUTS
    and as_bool(ASSOCIATION_FIXED_CONFIG.get("mash", False))
)

# Builds phylogeny distance matrix: {antibiotic}_phylogeny_fixed.tsv.
BUILD_FIXED_PHYLOGENY_INPUTS = (
    BUILD_FIXED_EFFECT_INPUTS
    and as_bool(ASSOCIATION_FIXED_CONFIG.get("phylogeny", False))
)

# Enables/disables all LMM kinship/similarity inputs.
BUILD_LMM_INPUTS = as_bool(ASSOCIATION_LMM_CONFIG.get("enabled", False))

# Builds phylogeny kinship matrix: {antibiotic}_phylogeny_lmm.tsv.
BUILD_LMM_PHYLOGENY_INPUTS = (
    BUILD_LMM_INPUTS
    and as_bool(ASSOCIATION_LMM_CONFIG.get("phylogeny", False))
)

# Builds genotype kinship matrix from SNP VCF: {antibiotic}_genotype_lmm.tsv.
BUILD_LMM_GENOTYPE_INPUTS = (
    BUILD_LMM_INPUTS
    and as_bool(ASSOCIATION_LMM_CONFIG.get("genotype", False))
)

# Full pyseer GitHub repository used for tutorial helper scripts.
# The conda pyseer package installs commands like pyseer and similarity_pyseer,
# but it does not install every helper script from the GitHub scripts/ folder.
PYSEER_REPO_URL = config.get("pyseer_repo_url", "https://github.com/mgalardini/pyseer.git")

# Local pipeline-managed clone location. This is under resources/, which is gitignored.
PYSEER_REPO_DIR = config.get("pyseer_repo_dir", "resources/pyseer")

# Generic marker proving the pyseer repository has been cloned and checked.
PYSEER_REPO_DONE = f"{PYSEER_REPO_DIR}/.clone_complete"

# Specific helper script used by phylogeny-based fixed-effect and LMM inputs.
PYSEER_PHYLOGENY_DISTANCE = f"{PYSEER_REPO_DIR}/scripts/phylogeny_distance.py"

QUAST_CONFIG = config.get("quast", {})
QUAST_REFERENCE = QUAST_CONFIG["reference"]
QUAST_ANNOTATION = QUAST_CONFIG["annotation"]


METADATA_TARGETS = expand(
    [
        f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_amr_metadata.csv",
        f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_sample_assembly_map.txt",
        f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_assembly_ids.txt",
        f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_preprocess_summary.txt",
    ],
    antibiotic=ANTIBIOTICS,
)

ASSEMBLY_TARGETS = expand(
    [
        f"{RESULTS_DIR}/{{antibiotic}}/assemblies/{{antibiotic}}_download_summary.txt",
        f"{RESULTS_DIR}/{{antibiotic}}/assemblies/{{antibiotic}}_assembly_download_manifest.tsv",
    ],
    antibiotic=ANTIBIOTICS,
)

QUAST_TARGETS = expand(
    f"{RESULTS_DIR}/{{antibiotic}}/qc/quast/{{antibiotic}}_report.html",
    antibiotic=ANTIBIOTICS,
) if RUN_QUAST else []

PROKKA_TARGETS = expand(
    f"{RESULTS_DIR}/{{antibiotic}}/annotations/prokka/{{antibiotic}}_gff_list.txt",
    antibiotic=ANTIBIOTICS,
)

PANAROO_QC_TARGETS = expand(
    [
        f"{RESULTS_DIR}/{{antibiotic}}/qc/panaroo/{{antibiotic}}_ngenes.txt",
        f"{RESULTS_DIR}/{{antibiotic}}/qc/panaroo/{{antibiotic}}_ncontigs.txt",
        f"{RESULTS_DIR}/{{antibiotic}}/qc/panaroo/{{antibiotic}}_mds_coords.txt",
    ],
    antibiotic=ANTIBIOTICS,
) if RUN_PANAROO_QC else []

PANAROO_PANGENOME_TARGETS = expand(
    [
        f"{RESULTS_DIR}/{{antibiotic}}/pangenome/panaroo/{{antibiotic}}_gene_presence_absence.Rtab",
        f"{RESULTS_DIR}/{{antibiotic}}/pangenome/panaroo/{{antibiotic}}_core_gene_alignment.aln",
        f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps.vcf",
    ],
    antibiotic=ANTIBIOTICS,
) if RUN_PANAROO_PANGENOME else []

SNP_NORMALIZATION_TARGETS = expand(
    [
        f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps.csv",
        f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only.vcf",
        f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only.csv",
        f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only_multiline.vcf",
        f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only_multiline.csv",
        f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only_multiline_no_star.vcf",
        f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only_multiline_no_star.csv",
    ],
    antibiotic=ANTIBIOTICS,
) if RUN_PANAROO_PANGENOME else []

KMER_TARGETS = expand(
    [
        f"{RESULTS_DIR}/{{antibiotic}}/kmers/fsm-lite/{{antibiotic}}_fsm_file_list.txt",
        f"{RESULTS_DIR}/{{antibiotic}}/kmers/fsm-lite/{{antibiotic}}_fsm_kmers.txt.gz",
    ],
    antibiotic=ANTIBIOTICS,
) if RUN_KMERS else []

ASSOCIATION_COMMON_INPUT_TARGETS = expand(
    f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/common/{{antibiotic}}_phenotype.tsv",
    antibiotic=ANTIBIOTICS,
)

ASSOCIATION_FIXED_MASH_TARGETS = expand(
    [
        f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_mash_sketch.msh",
        f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_mash_fixed.tsv",
    ],
    antibiotic=ANTIBIOTICS,
) if BUILD_FIXED_MASH_INPUTS else []

ASSOCIATION_FIXED_PHYLOGENY_TARGETS = expand(
    [
        f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_core_genome.tree",
        f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_phylogeny_fixed.tsv",
    ],
    antibiotic=ANTIBIOTICS,
) if BUILD_FIXED_PHYLOGENY_INPUTS else []

ASSOCIATION_LMM_PHYLOGENY_TARGETS = expand(
    f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/lmm/{{antibiotic}}_phylogeny_lmm.tsv",
    antibiotic=ANTIBIOTICS,
) if BUILD_LMM_PHYLOGENY_INPUTS else []

ASSOCIATION_LMM_GENOTYPE_TARGETS = expand(
    f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/lmm/{{antibiotic}}_genotype_lmm.tsv",
    antibiotic=ANTIBIOTICS,
) if BUILD_LMM_GENOTYPE_INPUTS else []

PYSEER_REPO_TARGETS = [
    PYSEER_REPO_DONE,
]

ASSOCIATION_INPUT_TARGETS = (
    PYSEER_REPO_TARGETS
    + ASSOCIATION_COMMON_INPUT_TARGETS
    + ASSOCIATION_FIXED_MASH_TARGETS
    + ASSOCIATION_FIXED_PHYLOGENY_TARGETS
    + ASSOCIATION_LMM_PHYLOGENY_TARGETS
    + ASSOCIATION_LMM_GENOTYPE_TARGETS
)

ASSOCIATION_TEST_TARGETS = []

FINAL_TARGETS = []

if BUILD_ANALYSIS_INPUTS:
    FINAL_TARGETS += (
        METADATA_TARGETS
        + ASSEMBLY_TARGETS
        + QUAST_TARGETS
        + PROKKA_TARGETS
        + PANAROO_QC_TARGETS
        + PANAROO_PANGENOME_TARGETS
        + SNP_NORMALIZATION_TARGETS
        + KMER_TARGETS
        + ASSOCIATION_INPUT_TARGETS
    )

if RUN_ASSOCIATION_TESTS:
    FINAL_TARGETS += ASSOCIATION_TEST_TARGETS

rule all:
    input:
        FINAL_TARGETS

rule preprocess_raw_data:
    input:
        lambda wildcards: f"{RAW_DATA_DIR}/{wildcards.antibiotic}_amr.csv"
    output:
        cleaned_csv=f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_amr_metadata.csv",
        sample_assembly_map=f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_sample_assembly_map.txt",
        assembly_ids=f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_assembly_ids.txt",
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
        assembly_ids=f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_assembly_ids.txt"
    output:
        summary=f"{RESULTS_DIR}/{{antibiotic}}/assemblies/{{antibiotic}}_download_summary.txt",
        manifest=f"{RESULTS_DIR}/{{antibiotic}}/assemblies/{{antibiotic}}_assembly_download_manifest.tsv"
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
            --antibiotic {wildcards.antibiotic} \
            --retries {params.retries} \
            --batch-size {params.batch_size}
        """

rule run_quast:
    input:
        manifest=f"{RESULTS_DIR}/{{antibiotic}}/assemblies/{{antibiotic}}_assembly_download_manifest.tsv",
        reference=QUAST_REFERENCE,
        annotation=QUAST_ANNOTATION
    output:
        report=f"{RESULTS_DIR}/{{antibiotic}}/qc/quast/{{antibiotic}}_report.html",
        report_txt=f"{RESULTS_DIR}/{{antibiotic}}/qc/quast/{{antibiotic}}_report.txt",
        report_tsv=f"{RESULTS_DIR}/{{antibiotic}}/qc/quast/{{antibiotic}}_report.tsv"
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

        mv {params.output_dir}/report.html {output.report}
        mv {params.output_dir}/report.txt {output.report_txt}
        mv {params.output_dir}/report.tsv {output.report_tsv}
        """

rule annotate_assemblies:
    input:
        manifest=f"{RESULTS_DIR}/{{antibiotic}}/assemblies/{{antibiotic}}_assembly_download_manifest.tsv"
    output:
        gff_list=f"{RESULTS_DIR}/{{antibiotic}}/annotations/prokka/{{antibiotic}}_gff_list.txt"
    conda:
        "envs/prokka_panaroo.yaml"
    threads: 4
    params:
        assemblies_dir=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/assemblies",
        output_dir=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/annotations/prokka"
    shell:
        r"""
        mkdir -p {params.output_dir}
        rm -f {output.gff_list}

        awk -F '\t' 'NR > 1 && $4 == "downloaded" {{print $1 "\t" $2}}' {input.manifest} |
        while IFS=$'\t' read -r assembly_id fasta_file
        do
            prokka \
                --outdir {params.output_dir}/${{assembly_id}} \
                --prefix ${{assembly_id}} \
                --cpus {threads} \
                --genus Staphylococcus \
                --species aureus \
                --usegenus \
                {params.assemblies_dir}/${{fasta_file}}

            echo "{params.output_dir}/${{assembly_id}}/${{assembly_id}}.gff" >> {output.gff_list}
        done
        """

rule run_panaroo_qc:
    input:
        gff_list=f"{RESULTS_DIR}/{{antibiotic}}/annotations/prokka/{{antibiotic}}_gff_list.txt"
    output:
        ngenes=f"{RESULTS_DIR}/{{antibiotic}}/qc/panaroo/{{antibiotic}}_ngenes.txt",
        ncontigs=f"{RESULTS_DIR}/{{antibiotic}}/qc/panaroo/{{antibiotic}}_ncontigs.txt",
        mds=f"{RESULTS_DIR}/{{antibiotic}}/qc/panaroo/{{antibiotic}}_mds_coords.txt"
    conda:
        "envs/prokka_panaroo.yaml"
    threads: PANAROO_QC_THREADS
    params:
        output_dir=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/qc/panaroo",
        graph_type=PANAROO_QC_GRAPH_TYPE
    shell:
        """
        panaroo-qc \
            -i {input.gff_list} \
            -o {params.output_dir} \
            --graph_type {params.graph_type} \
            -t {threads}

        mv {params.output_dir}/ngenes.txt {output.ngenes}
        mv {params.output_dir}/ncontigs.txt {output.ncontigs}
        mv {params.output_dir}/mds_coords.txt {output.mds}
        """

rule run_panaroo_pangenome:
    input:
        gff_list=f"{RESULTS_DIR}/{{antibiotic}}/annotations/prokka/{{antibiotic}}_gff_list.txt"
    output:
        rtab=f"{RESULTS_DIR}/{{antibiotic}}/pangenome/panaroo/{{antibiotic}}_gene_presence_absence.Rtab",
        core_alignment=f"{RESULTS_DIR}/{{antibiotic}}/pangenome/panaroo/{{antibiotic}}_core_gene_alignment.aln"
    conda:
        "envs/prokka_panaroo.yaml"
    threads: PANAROO_THREADS
    params:
        output_dir=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/pangenome/panaroo",
        clean_mode=PANAROO_CLEAN_MODE,
        alignment=PANAROO_ALIGNMENT
    shell:
        """
        panaroo \
            -i {input.gff_list} \
            -o {params.output_dir} \
            --clean-mode {params.clean_mode} \
            -a {params.alignment} \
            -t {threads}

        mv \
            {params.output_dir}/gene_presence_absence.Rtab \
            {output.rtab}

        mv \
            {params.output_dir}/core_gene_alignment.aln \
            {output.core_alignment}
        """

rule core_genome_snp:
    input:
        core_alignment=f"{RESULTS_DIR}/{{antibiotic}}/pangenome/panaroo/{{antibiotic}}_core_gene_alignment.aln"
    output:
        vcf=f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps.vcf"
    conda:
        "envs/snp_sites.yaml"
    threads: 1
    shell:
        """
        snp-sites \
            -v \
            -o {output.vcf} \
            {input.core_alignment}
        """

rule normalize_core_snps:
    input:
        vcf=f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps.vcf"
    output:
        raw_csv=f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps.csv",
        snps_only_vcf=f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only.vcf",
        snps_only_csv=f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only.csv",
        multiline_vcf=f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only_multiline.vcf",
        multiline_csv=f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only_multiline.csv",
        no_star_vcf=f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only_multiline_no_star.vcf",
        no_star_csv=f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only_multiline_no_star.csv"
    conda:
        "envs/snp_sites.yaml"
    shell:
        """
        python scripts/vcf_to_csv.py \
            --input-vcf {input.vcf} \
            --output-csv {output.raw_csv}

        bcftools view \
            -v snps \
            {input.vcf} \
            -Ov \
            -o {output.snps_only_vcf}

        python scripts/vcf_to_csv.py \
            --input-vcf {output.snps_only_vcf} \
            --output-csv {output.snps_only_csv}

        bcftools norm \
            -m -any \
            {output.snps_only_vcf} \
            -Ov \
            -o {output.multiline_vcf}

        python scripts/vcf_to_csv.py \
            --input-vcf {output.multiline_vcf} \
            --output-csv {output.multiline_csv}

        bcftools view \
            -e 'ALT="*"' \
            {output.multiline_vcf} \
            -Ov \
            -o {output.no_star_vcf}

        python scripts/vcf_to_csv.py \
            --input-vcf {output.no_star_vcf} \
            --output-csv {output.no_star_csv}
        """

rule prepare_association_phenotype:
    input:
        metadata=f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_amr_metadata.csv"
    output:
        phenotype=f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/common/{{antibiotic}}_phenotype.tsv"
    conda:
        "envs/preprocess.yaml"
    threads: 1
    params:
        phenotype_column=ASSOCIATION_PHENOTYPE_COLUMN
    shell:
        """
        mkdir -p $(dirname {output.phenotype})

        python -c '
import csv

with open("{input.metadata}", newline="") as handle, open("{output.phenotype}", "w") as out:
    reader = csv.DictReader(handle)
    for row in reader:
        sample = row["assembly_ID"]
        phenotype = row["{params.phenotype_column}"]
        if sample and phenotype:
            out.write(sample + "\\t" + phenotype + "\\n")
'
        """

rule association_mash_sketch:
    input:
        manifest=f"{RESULTS_DIR}/{{antibiotic}}/assemblies/{{antibiotic}}_assembly_download_manifest.tsv"
    output:
        sketch=f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_mash_sketch.msh"
    conda:
        "envs/gwas_inputs.yaml"
    threads: 1
    params:
        assemblies_dir=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/assemblies",
        sketch_prefix=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/association/inputs/fixed_effects/{wildcards.antibiotic}_mash_sketch",
        sketch_size=ASSOCIATION_MASH_SKETCH_SIZE
    shell:
        """
        mkdir -p $(dirname {output.sketch})

        mash sketch \
            -s {params.sketch_size} \
            -o {params.sketch_prefix} \
            {params.assemblies_dir}/*.fa
        """

rule association_mash_fixed:
    input:
        sketch=f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_mash_sketch.msh"
    output:
        distances=f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_mash_fixed.tsv"
    conda:
        "envs/gwas_inputs.yaml"
    threads: 1
    shell:
        """
        mash dist {input.sketch} {input.sketch} | square_mash > {output.distances}
        """

rule association_core_tree:
    input:
        alignment=f"{RESULTS_DIR}/{{antibiotic}}/pangenome/panaroo/{{antibiotic}}_core_gene_alignment.aln"
    output:
        tree=f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_core_genome.tree"
    conda:
        "envs/gwas_inputs.yaml"
    threads: 4
    shell:
        """
        mkdir -p $(dirname {output.tree})

        FastTree \
            -nt \
            -gtr \
            {input.alignment} \
            > {output.tree}
        """

rule clone_pyseer_repo:
    output:
        done=PYSEER_REPO_DONE
    conda:
        "envs/gwas_inputs.yaml"
    params:
        repo_url=PYSEER_REPO_URL,
        repo_dir=PYSEER_REPO_DIR,
        phylogeny_distance=PYSEER_PHYLOGENY_DISTANCE
    shell:
        """
        if [ ! -d {params.repo_dir}/.git ]; then
            mkdir -p $(dirname {params.repo_dir})
            git clone {params.repo_url} {params.repo_dir}
        fi

        test -f {params.phylogeny_distance}
        touch {output.done}
        """

rule association_phylogeny_fixed:
    input:
        tree=f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_core_genome.tree",
        pyseer_repo=PYSEER_REPO_DONE
    output:
        distances=f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_phylogeny_fixed.tsv"
    conda:
        "envs/gwas_inputs.yaml"
    threads: 1
    params:
        phylogeny_distance=PYSEER_PHYLOGENY_DISTANCE
    shell:
        """
        python {params.phylogeny_distance} {input.tree} > {output.distances}
        """

rule association_phylogeny_lmm:
    input:
        tree=f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/fixed_effects/{{antibiotic}}_core_genome.tree",
        pyseer_repo=PYSEER_REPO_DONE
    output:
        kinship=f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/lmm/{{antibiotic}}_phylogeny_lmm.tsv"
    conda:
        "envs/gwas_inputs.yaml"
    threads: 1
    params:
        phylogeny_distance=PYSEER_PHYLOGENY_DISTANCE
    shell:
        """
        mkdir -p $(dirname {output.kinship})

        python {params.phylogeny_distance} --lmm {input.tree} > {output.kinship}
        """

rule association_genotype_lmm:
    input:
        vcf=f"{RESULTS_DIR}/{{antibiotic}}/snps/snp-sites/{{antibiotic}}_core_snps_only_multiline_no_star.vcf",
        samples=f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_assembly_ids.txt"
    output:
        kinship=f"{RESULTS_DIR}/{{antibiotic}}/association/inputs/lmm/{{antibiotic}}_genotype_lmm.tsv"
    conda:
        "envs/gwas_inputs.yaml"
    threads: 1
    shell:
        """
        mkdir -p $(dirname {output.kinship})

        similarity_pyseer --vcf {input.vcf} {input.samples} > {output.kinship}
        """

rule count_kmers:
    input:
        sample_map=f"{RESULTS_DIR}/{{antibiotic}}/metadata/{{antibiotic}}_sample_assembly_map.txt",
        manifest=f"{RESULTS_DIR}/{{antibiotic}}/assemblies/{{antibiotic}}_assembly_download_manifest.tsv"
    output:
        file_list=f"{RESULTS_DIR}/{{antibiotic}}/kmers/fsm-lite/{{antibiotic}}_fsm_file_list.txt",
        kmers=f"{RESULTS_DIR}/{{antibiotic}}/kmers/fsm-lite/{{antibiotic}}_fsm_kmers.txt.gz"
    conda:
        "envs/fsm_lite.yaml"
    threads: 1
    params:
        assemblies_dir=lambda wildcards: f"{RESULTS_DIR}/{wildcards.antibiotic}/assemblies",
        min_kmer=KMER_MIN,
        max_kmer=KMER_MAX
    shell:
        """
        mkdir -p $(dirname {output.kmers})

        cp {input.sample_map} {output.file_list}

        project_dir="$PWD"
        cd {params.assemblies_dir}

        fsm-lite \
            -l "$project_dir/{output.file_list}" \
            -s {params.min_kmer} \
            -S {params.max_kmer} \
            -v \
            -t fsm_kmers \
        | gzip -c - > "$project_dir/{output.kmers}"
        """
