# Cardano's block cost analysis
A home for Tweag's investigation into the cost structure of Cardano block validation

## Did you know?

Some early-project observations

The smallest a block has ever been on mainnet is 633 bytes. The largest is 648KB
(633KiB). For a mean average of 17KiB per block.

There seems to be trends in block size, see how it evolves over time:

![Block size over time, smoothed over 1000 samples](./assets/overtime.png)

Most blocks are pretty small though

![Distribution of block size, as a 100-bin histogram](./assets/block-distrib.png)
