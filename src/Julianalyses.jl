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
using DecisionTree
using MLJ
using SymbolicRegression

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
      SUM(Tx."step_budget") AS "total_step_budget",
      SUM(Tx."mem_budget") AS "total_mem_budget",
      SUM(Tx.min_fee) AS total_min_fee,
      SUM(0.276*Tx.size_reference_scripts + 0.182 * (Tx.size_inputs - Tx.size_reference_inputs)) as model,
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
      -- MAX(Tx."step_budget") AS max_step_budget,
      -- MAX(Tx."mem_budget") AS max_mem_budget,
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
      Bench.mut_ErrorApplyingBlock = false AND
      Bench.mut_blockApply > 30000
    GROUP BY
      Block.block_no, Bench.mut_blockApply
    ;"""))
# unclear: except for the last column name which is a bit shifty and spans
# several columns, why doesn't duckdb manage to parse this header?

# Pearson correlation of all the columns with the benchmark
function correl()
	correlations = Dict()
	for col in names(blocks)
	    if col != "mut_blockApply"
	        correlations[col] = cor(blocks[!, col], blocks.mut_blockApply)
	    end
	end
    sort(collect(correlations), by=x->abs(x[2]), rev=true)
end

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
function multi_linear_reg()
    # Manually selecting terms.
    predictors=(# term("total_#script_wits")&term("total_script_wits_size"),
                # term("total_script_wits_size"),
                # term("total_#addr_wits"),
                term("total_size_reference_scripts"),
                term("total_datum_size"),
                # term("total_#inputs")&term("total_size_inputs"),
                term("total_size_nonref_inputs"),
                term("total_#outputs"),
                # term("total_#reference_inputs")&term("total_size_reference_inputs"),
                # term("total_size_nonscript_reference_inputs"),
                term("total_step_budget"),
                term("total_mem_budget"),
                )
    lin_regs=lm((term(:mut_blockApply) ~ sum(predictors)), blocks)
    coeftable(lin_regs)
end


## Random-forest feature importance
function random_forest_reg()
	X = select(blocks,
	            "total_#script_wits",
	            "total_script_wits_size",
	            "total_#addr_wits",
	            "total_size_reference_scripts",
	            "total_datum_size",
	            "total_#inputs",
	            "total_size_nonref_inputs",
	            "total_#outputs",
	            "total_#reference_inputs",
	            "total_size_nonscript_reference_inputs",
	            "total_step_budget",
	            "total_mem_budget",
	)
	y = blocks.mut_blockApply

	Forest = @load RandomForestRegressor pkg=DecisionTree
	model = Forest(n_trees=100, max_depth=10)
	
	mach = machine(model, float.(X), float.(y))
	MLJ.fit!(mach)
    
    feature_importances(Julianalyses.mach)
end
# Result:
# :total_size_reference_scripts => 0.23312378026392577
#                       :total_mem_budget => 0.2055821183707218
#                      :total_step_budget => 0.14426048730095462
#               :total_size_nonref_inputs => 0.1266131347211967
#                Symbol("total_#outputs") => 0.11402263893056437
#                 Symbol("total_#inputs") => 0.07900886534094251
#       Symbol("total_#reference_inputs") => 0.03106428943141968
#            Symbol("total_#script_wits") => 0.019654678133467825
#              Symbol("total_#addr_wits") => 0.016066162348496463
#                 :total_script_wits_size => 0.013115814129247394
#  :total_size_nonscript_reference_inputs => 0.011147997216749549
#                       :total_datum_size => 0.006340033812313445

## TODO: plot the predicted y (I think this looks like `ŷ = predict(mach, X)`) against the real y.

# Symbolic equation regression
function sym_reg()
    X2 = select(blocks,
        # "total_#script_wits",
        # "total_script_wits_size",
        # "total_#addr_wits",
        "total_size_reference_scripts",
        "total_datum_size",
        # "total_#inputs",
        "total_size_nonref_inputs",
        "total_#outputs",
        # "total_#reference_inputs",
        # "total_size_nonscript_reference_inputs",
        "total_step_budget",
        "total_mem_budget",
    )
    eqn_model = SRRegressor(
        niterations=1000,
        binary_operators=[+, -, *, /],
        unary_operators=[log, exp],
    )

    eqn_mach = machine(eqn_model, float.(X2), float.(y))
    MLJ.fit!(eqn_mach)
    report(eqn_mach)
end

end # module Julianalyses
