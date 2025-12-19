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

# Connect to the DuckDB database file.
con = DuckDB.DB(config["database"]["file"])

# A data frame
blocks = DataFrame(DuckDB.query(con, "SELECT \"slot#\", \"block_size\" FROM '$src_blocks'"))


## Histogram: distribution of block sizes
hist = barhist(
    blocks.block_size,
    bins = 100,
    xlabel = "Block size (Bytes)",
    ylabel = "Count",
    label = "mainnet",
    title = "Histogram of block size (100 bins)",
)
png(hist,"block-distrib.png")

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

end # module Julianalyses
