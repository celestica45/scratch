# Bacterial Association Pipeline

## Clone

```bash
git clone https://github.com/celestica45/scratch.git
cd scratch
```

## Minimum Requirements

Install:

- Git
- Conda or Mamba
- Snakemake

Example:

```bash
conda install -c conda-forge -c bioconda snakemake mamba
```

Pipeline tools are installed by Snakemake using the conda env files in `envs/`.

The first input-building run may require internet access because the workflow downloads assemblies and clones the pyseer tutorial repository.

## Config

Edit:

```bash
config/config.yaml
```

Main switches:

| build_analysis_inputs | run_association_tests | Meaning |
|---|---|---|
| false | false | Build nothing from `rule all`. |
| true | false | Build preprocessing and association input files only. |
| false | true | Run association tests only, using existing inputs. |
| true | true | Build inputs and run association tests. |

Recommended first run:

```yaml
build_analysis_inputs: true
run_association_tests: false
```

Freeze inputs after they are created:

```yaml
build_analysis_inputs: false
run_association_tests: false
```

Later, run association tests only:

```yaml
build_analysis_inputs: false
run_association_tests: true
```

## Association Config

```yaml
association:
  phenotype_column: transformed_mic
  mash_sketch_size: 10000

  snp_gwas:
    min_af: 0.02
    max_af: 0.98
    max_dimensions: 10
    lineage: true
    print_samples: true

  gwas_tests:
    snps:
      fixed_effects:
        mash: true
        phylogeny: true
      lmm:
        phylogeny: true
        genotype: true
    genes: false
    kmers: false
```

`fixed_effects` and `lmm` are not top-level blocks under `association` anymore. Association input files are always requested when `build_analysis_inputs: true`.

The phenotype output is always:

```text
{antibiotic}_phenotype.tsv
```

The phenotype column in config controls which metadata column is written into that file. Pyseer requires a header row, so the pipeline writes phenotype files like:

```text
samples	phenotype
GCA_015619305.3	2.0
```

### How The Switches Connect

`build_analysis_inputs` builds all inputs needed before GWAS. This includes:

- phenotype TSV
- SNP preprocessing outputs
- mash fixed-effect distance matrix
- phylogeny fixed-effect distance matrix
- phylogeny LMM kinship matrix
- genotype LMM kinship matrix

`run_association_tests` runs selected GWAS tests from `association.gwas_tests`.

Currently implemented:

| Config switch | GWAS run when true |
|---|---|
| `association.gwas_tests.snps.fixed_effects.mash` | SNP pyseer with `--distances {antibiotic}_mash_fixed.tsv` |
| `association.gwas_tests.snps.fixed_effects.phylogeny` | SNP pyseer with `--distances {antibiotic}_phylogeny_fixed.tsv` |
| `association.gwas_tests.snps.lmm.phylogeny` | SNP pyseer LMM with `--similarity {antibiotic}_phylogeny_lmm.tsv` |
| `association.gwas_tests.snps.lmm.genotype` | SNP pyseer LMM with `--similarity {antibiotic}_genotype_lmm.tsv` |

Not implemented yet:

| Config switch | Current behavior |
|---|---|
| `association.gwas_tests.genes` | Reserved for future gene presence/absence GWAS. |
| `association.gwas_tests.kmers` | Reserved for future k-mer GWAS. |

### Mash Distance Labels

Mash distances are created with the same tutorial-style command:

```bash
mash dist mash_sketch.msh mash_sketch.msh | square_mash
```

The `square_mash` command strips assembly version suffixes from sample names. The workflow restores versioned sample IDs after `square_mash` using:

```text
results/{antibiotic}/assemblies/{antibiotic}_assembly_download_manifest.tsv
```

This keeps the mash distance matrix aligned with phenotype, VCF, and phylogeny sample IDs.

### Possible Config Cases

| Config case | Result |
|---|---|
| `build_analysis_inputs: false` and `run_association_tests: false` | `rule all` builds nothing. |
| `build_analysis_inputs: true` and `run_association_tests: false` | Builds preprocessing and all association input files only. |
| `build_analysis_inputs: false` and `run_association_tests: true` | Runs selected GWAS tests using existing input files. |
| `build_analysis_inputs: true` and `run_association_tests: true` | Builds inputs and runs selected GWAS tests. |
| all `association.gwas_tests.*` values are `false` | No GWAS test target groups are requested. |

Recommended first run:

```yaml
build_analysis_inputs: true
run_association_tests: false
```

After inputs are complete, freeze them and run SNP GWAS:

```yaml
build_analysis_inputs: false
run_association_tests: true

association:
  gwas_tests:
    snps:
      fixed_effects:
        mash: true
        phylogeny: true
      lmm:
        phylogeny: true
        genotype: true
    genes: false
    kmers: false
```

Fixed-effect files use:

```text
*_fixed.tsv
```

LMM files use:

```text
*_lmm.tsv
```

SNP GWAS outputs are organized by the population-structure correction method:

```text
results/{antibiotic}/association/tests/snps/mash_fixed/
results/{antibiotic}/association/tests/snps/phylogeny_fixed/
results/{antibiotic}/association/tests/snps/phylogeny_lmm/
results/{antibiotic}/association/tests/snps/genotype_lmm/
```

Within each method folder:

```text
*_SNPs.tsv = pyseer SNP association result table
*_summary.txt = pyseer stderr run summary
*_lineage_effects.tsv = lineage effect summary when lineage is enabled
```

Example SNP result files:

```text
results/{antibiotic}/association/tests/snps/mash_fixed/{antibiotic}_snps_mash_fixed_SNPs.tsv
results/{antibiotic}/association/tests/snps/phylogeny_fixed/{antibiotic}_snps_phylogeny_fixed_SNPs.tsv
results/{antibiotic}/association/tests/snps/phylogeny_lmm/{antibiotic}_snps_phylogeny_lmm_SNPs.tsv
results/{antibiotic}/association/tests/snps/genotype_lmm/{antibiotic}_snps_genotype_lmm_SNPs.tsv
```

When `association.snp_gwas.lineage: true`, pyseer also writes lineage-effect summaries:

```text
results/{antibiotic}/association/tests/snps/mash_fixed/{antibiotic}_snps_mash_fixed_lineage_effects.tsv
results/{antibiotic}/association/tests/snps/phylogeny_lmm/{antibiotic}_snps_phylogeny_lmm_lineage_effects.tsv
```

This step only runs pyseer. Post-GWAS analysis, plots, and annotation will be added separately.

## Run

Dry-run:

```bash
XDG_CACHE_HOME=/tmp TMPDIR=/tmp snakemake -n --use-conda --rerun-triggers mtime
```

Actual run:

```bash
XDG_CACHE_HOME=/tmp TMPDIR=/tmp snakemake --use-conda --cores 4 --rerun-triggers mtime
```

## Important Outputs

Normalized SNP input:

```text
results/{antibiotic}/snps/snp-sites/{antibiotic}_core_snps_only_multiline_no_star.vcf
results/{antibiotic}/snps/snp-sites/{antibiotic}_core_snps_only_multiline_no_star.csv
```

Phenotype TSV:

```text
results/{antibiotic}/association/inputs/common/{antibiotic}_phenotype.tsv
```

Fixed-effect inputs:

```text
results/{antibiotic}/association/inputs/fixed_effects/{antibiotic}_mash_fixed.tsv
results/{antibiotic}/association/inputs/fixed_effects/{antibiotic}_phylogeny_fixed.tsv
```

LMM inputs:

```text
results/{antibiotic}/association/inputs/lmm/{antibiotic}_phylogeny_lmm.tsv
results/{antibiotic}/association/inputs/lmm/{antibiotic}_genotype_lmm.tsv
```

## Fixed Effects vs LMM

Fixed-effect pyseer uses distance matrices:

```bash
pyseer --phenotypes phenotype.tsv --vcf snps.vcf --distances mash_fixed.tsv
```

LMM pyseer uses kinship/similarity matrices:

```bash
pyseer --lmm --phenotypes phenotype.tsv --vcf snps.vcf --similarity genotype_lmm.tsv
```

## Pyseer Tutorial Scripts

The conda `pyseer` package installs commands such as:

```text
pyseer
square_mash
similarity_pyseer
```

However, the pyseer tutorial also uses helper scripts from the GitHub repository, including:

```text
scripts/phylogeny_distance.py
```

This pipeline clones the full pyseer repository automatically into:

```text
resources/pyseer/
```

The clone is represented by this Snakemake target:

```text
resources/pyseer/.clone_complete
```

The phylogeny rules call:

```bash
python resources/pyseer/scripts/phylogeny_distance.py ...
```

The clone source is configured in `config/config.yaml`:

```yaml
pyseer_repo_url: https://github.com/mgalardini/pyseer.git
pyseer_repo_dir: resources/pyseer
```

## Tree Building

The pipeline uses FastTree:

```bash
FastTree -nt -gtr core_gene_alignment.aln > core_genome.tree
```
