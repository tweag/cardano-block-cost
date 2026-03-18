module Julianalyses


using DataFrames
using Statistics
using DuckDB
using Plots
using StatsPlots
using RollingFunctions
using Cairo
using Fontconfig
using TOML
using GLM, StatsModels

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
      Block.block_no,
      Bench.mut_blockApply,
      SUM(Tx."#script_wits") AS "total_#script_wits",
      SUM(Tx."#addr_wits") AS "total_#addr_wits",
      SUM(Tx.script_wits_size) AS total_script_wits_size,
      SUM(Tx.size_reference_scripts) AS total_size_reference_scripts,
      SUM(Tx.datum_size) AS total_datum_size,
      SUM(Tx."#inputs") AS "total_#inputs",
      SUM(Tx.size_inputs) AS total_size_inputs,
      SUM(Tx.size_inputs)-SUM(Tx."size_reference_inputs") AS total_size_nonref_inputs,
      SUM(Tx."#outputs") AS "total_#outputs",
      SUM(Tx."#reference_inputs") AS "total_#reference_inputs",
      SUM(Tx."size_reference_inputs") AS total_size_reference_inputs,
      SUM(Tx."size_reference_inputs")-SUM(Tx.size_reference_scripts) AS total_size_nonscript_reference_inputs,
      SUM(Tx."#certs") AS "total_#certs",
      SUM(Tx."#pool_certs") AS "total_#pool_certs",
      SUM(Tx."#gov_certs") AS "total_#gov_certs",
      SUM(Tx."#deleg_certs") AS "total_#deleg_certs",
      SUM(Tx.min_fee) AS total_min_fee,
      -- MAX(Tx."#script_wits") AS "max_#script_wits",
      -- MAX(Tx."#addr_wits") AS "max_#addr_wits",
      -- MAX(Tx.script_wits_size) AS max_script_wits_size,
      -- MAX(Tx.size_reference_scripts) AS max_size_reference_scripts,
      -- MAX(Tx.datum_size) AS max_datum_size,
      -- MAX(Tx."#inputs") AS "max_#inputs",
      -- MAX(Tx.size_inputs) AS max_size_inputs,
      -- MAX(Tx."#outputs") AS "max_#outputs",
      -- MAX(Tx."#reference_inputs") AS "max_#reference_inputs",
      -- MAX(Tx."size_reference_inputs") AS max_size_reference_inputs,
      -- MAX(Tx."#certs") AS "max_#certs",
      -- MAX(Tx."#pool_certs") AS "max_#pool_certs",
      -- MAX(Tx."#gov_certs") AS "max_#gov_certs",
      -- MAX(Tx."#deleg_certs") AS "max_#deleg_certs",
      -- MAX(Tx.min_fee) AS max_min_fee
    FROM
      '$src_blocks' as Block
    JOIN read_csv('$src_bench', names=['slot', 'slotGap', 'totalTime', 'mut', 'gc', 'majGcCount', 'minGcCount', 'allocatedBytes', 'mut_forecast', 'mut_headerTick', 'mut_headerApply', 'mut_ErrorApplyingHeader', 'mut_blockTick', 'mut_blockApply', 'mut_ErrorApplyingBlock', 'blockBytes', 'extra_one', 'extra_two']) as Bench
    ON
      Block.slot_no = Bench.slot
    JOIN '$src_txs' as Tx
    ON
      Block.block_no = Tx.block_no
    WHERE
      Bench.mut_ErrorApplyingBlock = false
    GROUP BY
      Block.block_no, Bench.mut_blockApply
    ;"""))
# unclear: except for the last column name which is a bit shifty and spans
# several columns, why doesn't duckdb manage to parse this header?

## Histogram of divergence between fee calculation and actual benchmark
divergence = blocks.mut_blockApply ./ blocks.total_min_fee
divergence_hist = histogram(divergence, bins=50, xlabel="Apply time / min fee calculation", ylabel="Frequency", title="Distribution of divergence ratio",  xscale=:log10, yscale=:log10)

# Pearson correlation of all the columns with the benchmark
correlations = Dict()
for col in names(blocks)
    if col != "mut_blockApply"
        correlations[col] = cor(blocks[!, col], blocks.mut_blockApply)
    end
end

correlations = sort(collect(correlations), by=x->abs(x[2]), rev=true)
# Result:
 #             "max_#script_wits" => NaN
 #        "max_#reference_inputs" => NaN
 #                "total_min_fee" => 0.9216735282292824
 #  "total_size_reference_inputs" => 0.8869501576868908
 # "total_size_reference_scripts" => 0.8864507498507652
 #      "total_#reference_inputs" => 0.8134088452764734
 #           "total_#script_wits" => 0.8134088452764734
 #               "total_#outputs" => 0.8113411059548132
 #             "total_#addr_wits" => 0.7433565604307785
 #            "total_size_inputs" => 0.6497285123660923
 #                  "max_min_fee" => 0.6282616852152523
 #   "max_size_reference_scripts" => 0.6114395069105182
 #    "max_size_reference_inputs" => 0.6103841868379937
 #       "total_script_wits_size" => 0.5260806502852895
 #                "total_#inputs" => 0.4757648168970543
 #         "max_script_wits_size" => 0.44101727127154605
 #             "total_datum_size" => 0.34362718994084224
 #              "max_size_inputs" => 0.3406191715924063
 #                 "max_#outputs" => 0.284926867556569
 #               "max_datum_size" => 0.2577640871841093
 #                 "total_#certs" => 0.2559625601254871
 #           "total_#deleg_certs" => 0.25532325766784053
 #                   "max_#certs" => 0.21283275538898805
 #             "max_#deleg_certs" => 0.21232661056681895
 #               "max_#addr_wits" => 0.19922344955729748
 #                  "max_#inputs" => 0.1817287965564451
 #                     "block_no" => -0.07994423756252916
 #             "total_#gov_certs" => 0.025621151288029293
 #               "max_#gov_certs" => 0.025621151288029286
 #              "max_#pool_certs" => 0.01770089738603403
 #            "total_#pool_certs" => 0.016932487973567154
 #

## Linear regression
# predictors=setdiff(names(blocks), ["mut_blockApply", "total_min_fee"])
predictors=(# term("total_#script_wits")&term("total_script_wits_size"),
            term("total_script_wits_size"),
            # term("total_#addr_wits"),
            term("total_size_reference_scripts"),
            term("total_datum_size"),
            # term("total_#inputs")&term("total_size_inputs"),
            term("total_size_nonref_inputs"),
            # term("total_#outputs"),
            # term("total_#reference_inputs")&term("total_size_reference_inputs"),
            term("total_size_nonscript_reference_inputs"))
lin_regs=lm((term(:mut_blockApply) ~ sum(predictors)), blocks)
lin_reg_coefs=coeftable(lin_regs)



## I don't know why the reference line doesn't appear below, but at any rate, it
## doesn't look very informative. I guess, with hindsight, that the fact that the
## two axes aren't in the same unit means that the reference ought to be
## something else.
# scatter(blocks.total_min_fee, blocks.mut_blockApply, xlabel="Fee calculation", ylabel="Benchmark",  xscale=:log10, yscale=:log10)
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
