#!/usr/bin/env bash

STEP=10000000
START=0
END=140000000   # change as needed
TARGET=146620810
BASEDIR=$(dirname -- "$(readlink -f -- "$0")")
DBPATH=${DBPATH:-"$BASEDIR/db"}
CONFIGPATH=${CONFIGPATH:-"$BASEDIR/config"}

X=$START

while [ "$X" -lt "$END" ]; do
    NEXT=$((X + STEP))
    echo "Running: db-analyser --store-ledger $NEXT"
    nix run github:tweag/ouroboros-consensus/aspiwack/explore-cardano#db-analyser -- --db $DBPATH --config $CONFIGPATH --lmdb --store-ledger $NEXT
    X=$NEXT
done

echo "Running: db-analyser --store-ledger $TARGET"
nix run github:tweag/ouroboros-consensus/aspiwack/explore-cardano#db-analyser -- --db $DBPATH --config $CONFIGPATH --lmdb --store-ledger $TARGET
