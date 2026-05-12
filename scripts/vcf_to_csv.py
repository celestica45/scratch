import argparse
import csv


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-vcf", required=True)
    parser.add_argument("--output-csv", required=True)
    args = parser.parse_args()

    with open(args.input_vcf) as vcf, open(args.output_csv, "w", newline="") as out:
        writer = None

        for line in vcf:
            line = line.rstrip("\n")

            if not line:
                continue

            if line.startswith("##"):
                continue

            if line.startswith("#CHROM"):
                header = line.lstrip("#").split("\t")
                header[0] = "CHROM"
                writer = csv.writer(out)
                writer.writerow(header)
                continue

            if writer is None:
                raise ValueError("VCF header line #CHROM was not found")

            writer.writerow(line.split("\t"))


if __name__ == "__main__":
    main()
