#!/bin/zsh
# Usage: ./run.sh rich   (or: ./run.sh plain)
cd "$(dirname "$0")" && swift paste.swift "${1:-rich}"
