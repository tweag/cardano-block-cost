module Julianalyses


using DataFrames
using DuckDB
using Plots
using StatsPlots
using RollingFunctions
using Cairo
using Fontconfig
using TOML

# To run, this file expects, in pwd, a `config.toml` file of the following
# shape:
#
# ```toml
# [database]
# file = "/path/to/database.duckdb"

# [sources                            ]
# blocks = "/path/to/blocks.csv"
# transactions = "/path/to/transactions.csv"
# ```

config = TOML.parsefile("config.toml")
src_blocks = config["sources"]["blocks"]
src_bench = config["sources"]["benchmark"]
src_txs = config["sources"]["transactions"]

# Connect to the DuckDB database file.
con = DuckDB.DB(config["database"]["file"])

# Data frames
# blocks = DataFrame(DuckDB.query(con, "SELECT \"slot#\", \"block_size\" FROM '$src_blocks'"))
# txs = DataFrame(DuckDB.query(con, "SELECT count(*) as num, \"#script_wits\" FROM '$src_txs' GROUP BY \"#script_wits\""))
blocks = DataFrame(DuckDB.query(con,
    """
    SELECT
      Block.block_no, Bench.mut_headerApply, SUM(Tx.min_fee) AS total_min_fee
    FROM
      '$src_blocks' as Block
    JOIN read_csv('$src_bench', names=['slot', 'slotGap', 'totalTime', 'mut', 'gc', 'majGcCount', 'minGcCount', 'allocatedBytes', 'mut_forecast', 'mut_headerTick', 'mut_headerApply', 'mut_ErrorApplyingHeader', 'mut_blockTick', 'mut_blockApply', 'mut_ErrorApplyingBlock', 'blockBytes', 'extra_one', 'extra_two']) as Bench
    ON
      Block.slot_no = Bench.slot
    JOIN '$src_txs' as Tx
    ON
      Block.block_no = Tx.block_no
    WHERE
      Bench.mut_ErrorApplyingHeader = false
    GROUP BY
      Block.block_no, Bench.mut_headerApply
    ;"""))
# unclear: except for the last column name which is a bit shifty and spans
# several columns, why doesn't duckdb manage to parse this header?

## Histogram of divergence between fee calculation and actual benchmark
divergence = blocks.mut_headerApply ./ blocks.total_min_fee
divergence_hist = histogram(divergence, bins=50, xlabel="Apply time / min fee calculation", ylabel="Frequency", title="Distribution of divergence ratio",  xscale=:log10, yscale=:log10)
## I don't know why the reference line doesn't appear below, but at any rate, it
## doesn't look very informative. I guess, with hindsight, that the fact that the
## two axes aren't in the same unit means that the reference ought to be
## something else.
# scatter(blocks.total_min_fee, blocks.mut_headerApply, xlabel="Fee calculation", ylabel="Benchmark",  xscale=:log10, yscale=:log10)
# plot!(blocks.total_min_fee, blocks.total_min_fee, label="Y = X")  # reference line
# divergence_scatter= current()

## Histogram: distribution of block sizes
# hist = barhist(
#     blocks.block_size,
#     bins = 100,
#     xlabel = "Block size (Bytes)",
#     ylabel = "Count",
#     label = "mainnet",
#     title = "Histogram of block size (100 bins)",
# )
# png(hist,"block-distrib.png")

## Block size over time (rolling average of 1000 blocks)
# smoothed_block_size = rollmean(blocks.block_size, 1000)
# corresponding_slots = last(blocks."slot#", length(smoothed_block_size))
# # I'm getting some errors here that I can't reproduce when I write it by
# # manually in the REPL.
# overtime = plot(
#     corresponding_slots,
#     # blocks."slot#",
#     smoothed_block_size,
#     # blocks.block_size,
#     xlabel = "Slot",
#     ylabel = "Block size smoothed (Bytes)",
#     label = "mainnet",
#     title = "Block size over time",
# )
# png(overtime,"overtime.png")

## Histogram: distribution of number of script witnesses
# script_wits_dist = barhist(
#     txs."#script_wits",
#     weights = txs.num,
#     bins = 10,
#     xlabel = "Number of script witnesses",
#     ylabel = "Count (logarithmic)",
#     yscale = :log10,
#     label = "mainnet",
#     title = "Histogram of number script witnesses (10 bins)",
# )
# png(script_wits_dist,"script-wits-distrib.png")

end # module Julianalyses
