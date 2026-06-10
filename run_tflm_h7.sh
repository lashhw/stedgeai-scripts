#!/bin/bash

if [ -z "$1" ]; then
    echo "usage: $0 MODELS_DIR"
    exit 1
fi

PROGRAMMER="/opt/st/stm32cubeide_2.1.1/plugins/com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.linux64_2.2.400.202601091506/tools/bin/STM32_Programmer_CLI"

PROJECT_DIR="$HOME/STM32CubeIDE/workspace_2.1.1/tflm_h7"
HEADER_FILE="$PROJECT_DIR/CM7/Core/Inc/run_tflm.h"
BUILD_DIR="$PROJECT_DIR/STM32CubeIDE/CM7/Release"
ELF_FILE="$BUILD_DIR/tflm_h7_CM7.elf"

MODELS_DIR="$1"
RESULTS_DIR="$PWD/results"

rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

run_model() {
    local MODEL_FILE="$1"
    local MODEL_NAME="$2"
    local RUN_DIR="$3"

    (
        set -e
        echo "tflm_main_$MODEL_NAME(tensor_arena, TENSOR_ARENA_SIZE, HAL_GetTick);" > "$HEADER_FILE"

        echo "==== BUILD ===="
        make -C "$BUILD_DIR" clean
        make -C "$BUILD_DIR" -j8 all
        cp "$ELF_FILE" "$RUN_DIR"

        echo "=== FLASH ==="
        "$PROGRAMMER" -c port=SWD -w "$ELF_FILE" -v -rst

        sleep 10s
    )

    if [ $? -eq 0 ]; then
        echo "=== SUCCESS ==="
    else
        echo "=== FAIL ==="
    fi
}

for MODEL_FILE in "$MODELS_DIR"/*.tflite; do
    test -f "$MODEL_FILE" || continue
    MODEL_NAME=$(basename "${MODEL_FILE%.*}")
    RUN_DIR="$RESULTS_DIR/$MODEL_NAME"
    mkdir -p "$RUN_DIR"
    run_model "$MODEL_FILE" "$MODEL_NAME" "$RUN_DIR" > "$RUN_DIR/run.log" 2>&1
done

echo "All jobs finished."
echo "Results are in: $RESULTS_DIR"
