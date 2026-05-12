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

  fixed_effects:
    mash: true
    phylogeny: true

  lmm:
    phylogeny: true
    genotype: true

  tests:
    snps: true
    genes: false
    kmers: false
```

The phenotype output is always:

```text
{antibiotic}_phenotype.tsv
```

The phenotype column in config controls which metadata column is written into that file.

### How The Switches Connect

`build_analysis_inputs` controls preprocessing and association input targets.

When `build_analysis_inputs: true`, these association switches add input files to `rule all`:

| Config switch | Target added when true |
|---|---|
| `association.fixed_effects.mash` | `results/{antibiotic}/association/inputs/fixed_effects/{antibiotic}_mash_fixed.tsv` |
| `association.fixed_effects.phylogeny` | `results/{antibiotic}/association/inputs/fixed_effects/{antibiotic}_phylogeny_fixed.tsv` |
| `association.lmm.phylogeny` | `results/{antibiotic}/association/inputs/lmm/{antibiotic}_phylogeny_lmm.tsv` |
| `association.lmm.genotype` | `results/{antibiotic}/association/inputs/lmm/{antibiotic}_genotype_lmm.tsv` |

`run_association_tests` controls GWAS result targets.

When `run_association_tests: true`, these switches choose which association test target groups are requested:

| Config switch | Current behavior |
|---|---|
| `association.tests.snps` | Connects to `SNP_ASSOCIATION_TEST_TARGETS`, currently empty until SNP pyseer rules are added. |
| `association.tests.genes` | Connects to `GENE_ASSOCIATION_TEST_TARGETS`, currently empty until gene pyseer rules are added. |
| `association.tests.kmers` | Connects to `KMER_ASSOCIATION_TEST_TARGETS`, currently empty until k-mer pyseer rules are added. |

For now, the test switches are already wired in the `Snakefile`, but no GWAS jobs run yet because the test target lists are intentionally empty.

### Possible Config Cases

| Config case | Result |
|---|---|
| `build_analysis_inputs: false` and `run_association_tests: false` | `rule all` builds nothing. |
| `build_analysis_inputs: true` and `run_association_tests: false` | Builds preprocessing and selected association input files only. |
| `build_analysis_inputs: false` and `run_association_tests: true` | Requests association test targets only. Currently no jobs are added because test target lists are empty. |
| `build_analysis_inputs: true` and `run_association_tests: true` | Builds selected inputs and selected test targets. Currently test targets are empty. |
| all `association.fixed_effects.*` values are `false` | No fixed-effect input matrices are requested. |
| all `association.lmm.*` values are `false` | No LMM input matrices are requested. |
| all `association.tests.*` values are `false` | No GWAS test target groups are requested. |

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
