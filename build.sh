#!/bin/bash
set -euo pipefail

sudo rm -rf ./work ./out ./tmp
mkdir -p ./work ./out ./tmp

export TMPDIR="$PWD/tmp"
export MAKEFLAGS=-j8

sudo mkarchiso -v -w "$PWD/work" -o "$PWD/out" "$PWD"
ls -lh ./out/