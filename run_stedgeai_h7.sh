#!/bin/bash

if [ -z "$1" ]; then
    echo "usage: $0 MODELS_DIR"
    exit 1
fi

export PATH="/opt/st/stm32cubeide_2.1.1/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.14.3.rel1.linux64_1.0.100.202602081740/tools/bin:$PATH"

STEDGEAI="/opt/ST/STEdgeAI/4.0/Utilities/linux/stedgeai"
PROGRAMMER="/opt/st/stm32cubeide_2.1.1/plugins/com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.linux64_2.2.400.202601091506/tools/bin/STM32_Programmer_CLI"

PROJECT_DIR="$HOME/.stm32cubeaistudio/workspace/stm32h7_template/.ai/run/run-1"
MEMPOOL_FILE="$PROJECT_DIR/.ai/mempools.json"
BUILD_DIR_CM7="$PROJECT_DIR/STM32CubeIDE/CM7/Release"
BUILD_DIR_CM4="$PROJECT_DIR/STM32CubeIDE/CM4/Release"
ELF_FILE_CM7="$BUILD_DIR_CM7/run-1_CM7.elf"
ELF_FILE_CM4="$BUILD_DIR_CM4/run-1_CM4.elf"

MODELS_DIR="$1"
RESULTS_DIR="$PWD/results"

BATCH_SIZE="1"
OPT="balanced"
NAME="network"
VERBOSITY="1"
C_API="st-ai"
TARGET="stm32h7"
SERIAL_DESC="serial:/dev/ttyACM0:115200"

rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

run_model() {
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
            --verbosity "$VERBOSITY" \
            --c-api "$C_API" \
            --target "$TARGET" \
            --workspace "$WS_DIR" \
            --output "$PROJECT_DIR" \
            --memory-pool "$MEMPOOL_FILE" \
            --quiet

        echo "==== BUILD CM7 ===="
        make -C "$BUILD_DIR_CM7" clean
        make -C "$BUILD_DIR_CM7" -j8 all

        echo "==== BUILD CM4 ===="
        make -C "$BUILD_DIR_CM4" clean
        make -C "$BUILD_DIR_CM4" -j8 all

        echo "=== FLASH ==="
        "$PROGRAMMER" -c port=SWD freq=8000 mode=UR reset=HWrst -e all
        "$PROGRAMMER" -c port=SWD freq=8000 mode=UR reset=HWrst -d "$ELF_FILE_CM7" -v
        "$PROGRAMMER" -c port=SWD freq=8000 mode=UR reset=HWrst -d "$ELF_FILE_CM4" -v -s 0x08000000
        sleep 10s

        echo "=== VALIDATE ==="
        "$STEDGEAI" validate \
            --model "$MODEL_FILE" \
            --batch-size "$BATCH_SIZE" \
            --mode target \
            --optimization "$OPT" \
            --name "$NAME" \
            --verbosity "$VERBOSITY" \
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

for MODEL_FILE in "$MODELS_DIR"/*.tflite "$MODELS_DIR"/*.onnx; do
    test -f "$MODEL_FILE" || continue
    MODEL_NAME=$(basename "${MODEL_FILE%.*}")
    RUN_DIR="$RESULTS_DIR/$MODEL_NAME"
    mkdir -p "$RUN_DIR"
    run_model "$MODEL_FILE" "$RUN_DIR" > "$RUN_DIR/run.log" 2>&1
done

echo "All jobs finished."
echo "Results are in: $RESULTS_DIR"
