#!/bin/bash

if [ -z "$1" ]; then
    echo "usage: $0 MODELS_DIR"
    exit 1
fi

export PATH="/opt/st/stm32cubeide_2.1.1/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.14.3.rel1.linux64_1.0.100.202602081740/tools/bin:$PATH"

STEDGEAI="/opt/ST/STEdgeAI/4.0/Utilities/linux/stedgeai"
PROGRAMMER="/opt/st/stm32cubeide_2.1.1/plugins/com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.linux64_2.2.400.202601091506/tools/bin/STM32_Programmer_CLI"

PROJECT_DIR="$HOME/.stm32cubeaistudio/workspace/stm32f7_template/.ai/run/run-1"
MEMPOOL_FILE="$PROJECT_DIR/.ai/mempools.json"
BUILD_DIR="$PROJECT_DIR/STM32CubeIDE/Release"
ELF_FILE="$BUILD_DIR/run-1.elf"

MODELS_DIR="$1"
RESULTS_DIR="$PWD/results"

BATCH_SIZE="1"
OPT="balanced"
NAME="network"
VERBOSITY="1"
C_API="st-ai"
TARGET="stm32f7"
SERIAL_DESC="serial:/dev/ttyACM0:115200"

AFTER_FLASH_SLEEP_TIME="3s"

rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

run_one_model() {
    local MODEL_FILE="$1"
    local RUN_DIR="$2"
    local WS_DIR="$RUN_DIR/st_ai_ws"
    local OUT_DIR="$RUN_DIR/st_ai_output"

    (
        set -e

        echo "=== GENERATE ==="
        "$STEDGEAI" generate \
            --model "$MODEL_FILE" \
            --batch-size "$BATCH_SIZE" \
            --mode target \
            --optimization "$OPT" \
            --name "$NAME" \
            --verbosity $VERBOSITY \
            --c-api "$C_API" \
            --target "$TARGET" \
            --workspace "$WS_DIR" \
            --output "$PROJECT_DIR" \
            --memory-pool "$MEMPOOL_FILE" \
            --quiet

        echo "==== BUILD ===="
        make -C "$BUILD_DIR" clean
        make -C "$BUILD_DIR" -j8 all

        echo "=== FLASH ==="
        "$PROGRAMMER" -c port=SWD -w "$ELF_FILE" -v -rst
        sleep "$AFTER_FLASH_SLEEP_TIME"

        echo "=== VALIDATE ==="
        "$STEDGEAI" validate \
            --model "$MODEL_FILE" \
            --batch-size "$BATCH_SIZE" \
            --mode target \
            --optimization "$OPT" \
            --name "$NAME" \
            --verbosity $VERBOSITY \
            --c-api "$C_API" \
            --target "$TARGET" \
            --workspace "$WS_DIR" \
            --output "$OUT_DIR" \
            --memory-pool "$MEMPOOL_FILE" \
            --desc "$SERIAL_DESC" \
            --save-csv \
            --quiet
    )

    if [ $? -eq 0 ]; then
        echo "=== SUCCESS ==="
    else
        echo "=== FAIL ==="
    fi
}

for MODEL_FILE in "$MODELS_DIR"/*.tflite; do
    RUN_DIR="$RESULTS_DIR/$(basename "$MODEL_FILE" .tflite)"
    mkdir -p "$RUN_DIR"
    LOG_FILE="$RUN_DIR/run.log"
    run_one_model "$MODEL_FILE" "$RUN_DIR" >> "$LOG_FILE" 2>&1
done

echo "All jobs finished."
echo "Results are in: $RESULTS_DIR"
