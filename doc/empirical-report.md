# Empirical evaluation of the cost of block application

> [!IMPORTANT]
> This report reports on early explorations of the structure of block costs. The
> data under study is still raw and will benefit from being regularised for
> better analyses. The report will evolve as understanding of the data
> progresses.

This reports on initial data analysis performed in order to start improving and
future proofing estimates of block application cost and of the minimum fee
calculation.

The data that was studied is blocks from the latest era spanning most of 2025.
Concretely from slot 146620842 to slot 173374535. The cost of application was
determined by running benchmark locally with the `db-analyser` tool from the
`ouroboros-consensus` repository. At this stage, the proxy for cost is purely in
terms of time (memory is ignored).

## Minimum fee calculation

The current minimum fee calculation performs rather well on most blocks but does
appear to significantly underestimate the cost of more expensive blocks. It can
be observerd on the log/log graph, where points below the line are underestimate
(a perfectly accurate estimate would have all the points on the line). We can
see that some are underestimated by several orders of magnitude

![min-fee-regr-log](empirical-report/min-fee-fit-log.png "Regression of mininimum fee vs block application
time in log/log scale")

The distribution is heavily skewed toward the lower cost blocks. This confuses
regression methods. For instance the regression coefficient is an apparently
excellent $0.92$, despite the severe disconnection on the slowest blocks. The
data will have to be appropriately regularised, as our experiments so far
indicate that fitting functions on the extremal regime doesn't yield good
prediction for the typical blocks and vice versa.

## Features

Here is the list of features of blocks that we have considered:

- **Number of script witnesses**: sum of the number of script witnesses in the
  transaction of the block
- **Size of script witnesses**: sum of the size (in bytes) of script witnesses embedded in
  the transaction of the block
- **Number of address witnesses**: sum of the number of address witnesses in the
  transaction of the block
- **Size of reference scripts**: sum of the sizes (in bytes) of reference scripts in
  transaction inputs.
- **Datum size**: sum of the sizes (in bytes) of the datum of each transaction
- **Number of inputs**: number of inputs across all transactions in the block.
- **Size of inputs**: sum of the size (in bytes) of all the (resolved) inputs of
  all transactions in the block.
- **Number of reference inputs**: number of reference inputs across all
  transactions in the block.
- **Size of reference inputs**: sum of the size (in bytes) of all the (resolved)
  reference inputs of all transactions in the block.
- **Number of outputs**: number of outputs across all transaction in the block.
- **Number of certificates**: number of certificates across all transactions in
  the block.
- **Number of pool certificates**: number of pool certificates across all transactions in
  the block.
- **Number of governance certificates**: number of governance certificates across all transactions in
  the block.
- **Number of deleg certificates**: number of deleg certificates across all transactions in
  the block.
- **Step budget**: total number of ex-unit steps allowed for the scripts in all
  transaction combined.
- **Memory budget**: sum of the ex-unit memory allowed for each script in
  transactions of the block.

To test for super-linearity we have also considered variants of the transaction
features where instead of summing over transaction, we take the maximum value
appear in a transaction in a block (for things like size of inputs, they are
still summed over all inputs of the transaction, and this value is compared to
take the largest among all transaction in the block). The max variants didn't
turn out to be interesting and are always worse predictors than their sum
counterparts.

## Random forest regression

Random forest regression partitions the space into section. It has proved pretty
resistant to extremal values. It doesn't, however, yield an explainable model.
It is the best that we have at the moment, however.

A useful feature of random forest is that it estimates (in proportions that sum
to 1) how sensitive the output is to various features. For our dataset it looks
as follows:

```
          :total_size_reference_scripts => 0.23312378026392577
                      :total_mem_budget => 0.2055821183707218
                     :total_step_budget => 0.14426048730095462
              :total_size_nonref_inputs => 0.1266131347211967
               Symbol("total_#outputs") => 0.11402263893056437
                Symbol("total_#inputs") => 0.07900886534094251
      Symbol("total_#reference_inputs") => 0.03106428943141968
           Symbol("total_#script_wits") => 0.019654678133467825
             Symbol("total_#addr_wits") => 0.016066162348496463
                :total_script_wits_size => 0.013115814129247394
 :total_size_nonscript_reference_inputs => 0.011147997216749549
                      :total_datum_size => 0.006340033812313445
```

This reads as
- the size of reference scripts accounts for 23% of the variation of block
  application time,
- the memory budget for 21%,
- the step budget for 14%,
- the size of non-reference inputs (that the total size of inputs minus the size
  of reference inputs) for 12%,
- the number of output for 11%,
- and the rest of the feature account for less than 10% each (and in fact, about
  10% total) of the variation.

This lets us focus the features we give to more explainable models, though this
hasn't yet yielded good models.

A probably counter-intuitive finding of the random forest regression is that the
memory budget seems to be more important than the step budget in determining the
time that it takes to apply block, this is not a phenomenon that we have tried
to investigate.

The model calculated by random-forest regression looks likes this in log/log
scale

![random-forest-regr-log](empirical-report/random-forest-fit-log.png "Regression of
the random forest model vs block application
time in log/log scale")

The visualisation is not ideal, as the linear regression is skewed upward by
overly numerous low values giving the impression of more and larger
underestimates than reality. But we can see that the model gives a decent
approximation in all regimes. We still have some outliers which aren't captured,
however.

### Comparison with the min fee calculation

The minimum fee is, at time of writing, calculated as follows


```haskell
module Cardano.Ledger.Conway.Tx where

getConwayMinFeeTx pp tx refScriptsSize =
  alonzoMinFeeTx pp tx <+> refScriptsFee
  where
    refScriptCostPerByte = unboundRational (pp ^. ppMinFeeRefScriptCostPerByteL)
    refScriptsFee =
      tierRefScriptFee
        (unboundRational $ pp ^. ppRefScriptCostMultiplierG)
        (fromIntegral @Word32 @Int . unNonZero $ pp ^. ppRefScriptCostStrideG)
        refScriptCostPerByte
        refScriptsSize
```

It's a linear combination of
- A base fee
- The size of the entire transaction
- The steps and memory budgets
- The size of reference scripts

We don't measure the size of transactions yet. But it will correlate with number
of inputs and outputs which are also significant factors. That being said the
size of the transaction should also correlate with the datum size which is an
element of little importance. So we may expect that the transaction size is a
bit coarse a measure. The major factor which seems not to have been taken into
account by the minimum fee calculation is toe size of resolved (non-reference)
inputs.
