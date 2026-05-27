set -x PATH /opt/st/stm32cubeide_2.1.1/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.14.3.rel1.linux64_1.0.100.202602081740/tools/bin $PATH
set STEDGEAI /opt/ST/STEdgeAI/4.0/Utilities/linux/stedgeai
set PROGRAMMER /opt/st/stm32cubeide_2.1.1/plugins/com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.linux64_2.2.400.202601091506/tools/bin/STM32_Programmer_CLI

set PROJECT_DIR $HOME/.stm32cubeaistudio/workspace/stm32f7_template/.ai/run/run-1
set MEMPOOL_FILE $PROJECT_DIR/.ai/mempools.json
set BUILD_DIR $PROJECT_DIR/STM32CubeIDE/Release
set ELF_FILE $BUILD_DIR/run-1.elf

set MODELS_DIR /mnt/shared/tflite
set RESULTS_DIR $PWD/results
set LOG_FILE $RESULTS_DIR/run.log

set TARGET stm32f7
set NAME network
set BATCH_SIZE 1
set OPT balanced
set C_API st-ai
set SERIAL_DESC serial:/dev/ttyACM0:115200

set AFTER_FLASH_SLEEP_TIME 3s

rm -rf $RESULTS_DIR
mkdir -p $RESULTS_DIR

function run_one_model --argument-names MODEL_FILE
    set RUN_DIR $RESULTS_DIR/(basename $MODEL_FILE .tflite)
    set WS_DIR $RUN_DIR/st_ai_ws
    set OUT_DIR $RUN_DIR/st_ai_output

    echo "=== RUNNING MODEL: $MODEL_FILE ==="
    mkdir -p $RUN_DIR

    echo "=== GENERATE ==="

    $STEDGEAI generate \
        --model $MODEL_FILE \
        --batch-size $BATCH_SIZE \
        --mode target \
        --optimization $OPT \
        --name $NAME \
        --c-api $C_API \
        --target $TARGET \
        --workspace $WS_DIR \
        --output $PROJECT_DIR \
        --memory-pool $MEMPOOL_FILE \
        --quiet
    or return 1

    echo "==== BUILD ===="

    make -C $BUILD_DIR clean
    or return 1

    make -C $BUILD_DIR -j8 all
    or return 1

    echo "=== FLASH ==="

    $PROGRAMMER -c port=SWD -w $ELF_FILE -v -rst
    or return 1

    sleep $AFTER_FLASH_SLEEP_TIME

    echo "=== VALIDATE ==="

    $STEDGEAI validate \
        --model $MODEL_FILE \
        --batch-size $BATCH_SIZE \
        --mode target \
        --optimization $OPT \
        --name $NAME \
        --c-api $C_API \
        --target $TARGET \
        --workspace $WS_DIR \
        --output $OUT_DIR \
        --desc $SERIAL_DESC \
        --memory-pool $MEMPOOL_FILE \
        --quiet
    or return 1

    echo "=== DONE: $MODEL_FILE ==="
end

for MODEL_FILE in $MODELS_DIR/*.tflite
    run_one_model $MODEL_FILE >> $LOG_FILE 2>&1
end

echo "All jobs finished."
echo "Results are in: $RESULTS_DIR"
