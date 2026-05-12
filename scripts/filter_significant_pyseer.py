import argparse

import pandas as pd


parser = argparse.ArgumentParser()
parser.add_argument("--limit", required=True)
parser.add_argument("--results", required=True)
parser.add_argument("--output", required=True)
args = parser.parse_args()

limits = pd.read_csv(args.limit, sep="\t", header=None)
p_threshold = float(limits.iloc[1, 1])

results = pd.read_csv(args.results, sep="\t")
filtered = results[results["lrt-pvalue"] < p_threshold]
filtered.to_csv(args.output, sep="\t", index=False)
