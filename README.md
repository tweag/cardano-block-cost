# Cardano's block cost analysis
A home for Tweag's investigation into the cost structure of Cardano block
validation

## Extract blocks with

``` sh
$ nix run github:tweag/ouroboros-consensus/aspiwack/explore-cardano#db-analyser -- --db path/to/db/ --config path/to/config.json --in-mem --dump-features --block-file path/to/blocks.csv --transaction-file path/to/transactions.csv --analyse-from 4492900
```

Where
- `--db` points to a directory with a node's block database
- `--config` points to the config file that the node used
- `--block-file` and `--transaction-file` point to possibly non-existent files,
  where the data will be dumped.

## Did you know?

Some early-project observations

### Blocks

The smallest a block has ever been on mainnet is 633 bytes. The largest is 648KB
(633KiB). For a mean average of 17KiB per block.

There seems to be trends in block size, see how it evolves over time:

![Block size over time, smoothed over 1000 samples](./assets/overtime.png)

Most blocks are pretty small though

![Distribution of block size, as a 100-bin histogram](./assets/block-distrib.png)

### Witnesses

Here's the distribution of the number of script witnesses in transactions

![Distribution of number of script witnesses in transactions, as a 10-bin
histogram, with logaritmic scale](./assets/script-wits-distrib.png)

