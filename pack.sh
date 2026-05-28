#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "usage: $0 INPUT_DIR OUTPUT_ZIP"
    exit 1
fi

INPUT_DIR=$1
OUTPUT_ZIP=$2

if [[ "$OUTPUT_ZIP" != /* ]]; then
    OUTPUT_ZIP="$PWD/$OUTPUT_ZIP"
fi

TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR/log"
mkdir -p "$TEMP_DIR/report"

for dir in "$INPUT_DIR"/*/; do
    [ -d "$dir" ] || continue
    dir_name=$(basename "$dir")

    if [ -f "$dir/run.log" ]; then
        cp "$dir/run.log" "$TEMP_DIR/log/${dir_name}.log"
    fi

    if [ -f "$dir/st_ai_output/network_validate_report.txt" ]; then
        cp "$dir/st_ai_output/network_validate_report.txt" "$TEMP_DIR/report/${dir_name}.txt"
    fi
done

(
    cd "$TEMP_DIR" || exit 1
    zip -rq "$OUTPUT_ZIP" log report
)
rm -rf "$TEMP_DIR"

echo "Result saved in $2"