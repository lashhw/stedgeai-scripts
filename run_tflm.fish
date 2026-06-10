test (count $argv) -eq 0 && exit 1

set input_file $argv[1]
set error_file error.txt

set header_file ~/STM32CubeIDE/workspace_2.1.1/tflm/Core/Inc/run_tflm.h
set cubeide /opt/st/stm32cubeide_2.1.1/stm32cubeide
set cubeprogrammer /opt/st/stm32cubeide_2.1.1/plugins/com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.linux64_2.2.400.202601091506/tools/bin/STM32_Programmer_CLI

rm -f $error_file

cat $input_file | while read -l model
    echo "Processing: $model"

    echo "tflm_main_$model(tensor_arena, TENSOR_ARENA_SIZE, HAL_GetTick);" > $header_file

    $cubeide --launcher.suppressErrors -nosplash -data ~/STM32CubeIDE/workspace_2.1.1 -application org.eclipse.cdt.managedbuilder.core.headlessbuild -cleanBuild tflm/Release
    
    if test $status -ne 0
        echo "$model: compile error" >> $error_file
        continue
    end

    $cubeprogrammer -c port=SWD -w ~/STM32CubeIDE/workspace_2.1.1/tflm/STM32CubeIDE/Release/tflm.elf -v -rst

    if test $status -ne 0
        echo "$model: program error" >> $error_file
        continue
    end

    sleep 10s
end
