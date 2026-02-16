#!/usr/bin/env bash

set -euo pipefail

#
# See instructions at https://mithril.network/doc/manual/getting-started/bootstrap-cardano-node
#

# Cardano network
export CARDANO_NETWORK=mainnet

# Aggregator API endpoint URL
export AGGREGATOR_ENDPOINT=auto:release-mainnet

# Genesis verification key
export GENESIS_VERIFICATION_KEY=$(curl --silent https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-mainnet/genesis.vkey)

# Ancillary verification key
export ANCILLARY_VERIFICATION_KEY=$(curl --silent https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-mainnet/ancillary.vkey)

# Digest of the latest produced cardano db snapshot for convenience of the demo
export SNAPSHOT_DIGEST=latest

# Download the latest snapshot
exec mithril-client cardano-db download latest --include-ancillary "$@"
