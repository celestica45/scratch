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

## Association Input Config

```yaml
association:
  phenotype_column: transformed_mic
  mash_sketch_size: 10000

  fixed_effects:
    enabled: true
    mash: true
    phylogeny: true

  lmm:
    enabled: true
    phylogeny: true
    genotype: true
```

The phenotype output is always:

```text
{antibiotic}_phenotype.tsv
```

The phenotype column in config controls which metadata column is written into that file.

Fixed-effect files use:

```text
*_fixed.tsv
```

LMM files use:

```text
*_lmm.tsv
```

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
