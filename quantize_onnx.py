import argparse
import numpy as np
import onnx
import os
import tempfile

from onnxruntime.quantization import (
    CalibrationDataReader,
    QuantFormat,
    QuantType,
    quantize_static,
)
from onnxruntime.quantization.shape_inference import quant_pre_process


class DummyCalibrationDataReader(CalibrationDataReader):
    def __init__(self, input_name, input_shape, num_samples):
        rng = np.random.default_rng(0)
        self.data = []
        for _ in range(num_samples):
            x = rng.uniform(
                low=-1.0,
                high=1.0,
                size=input_shape,
            ).astype(np.float32)
            self.data.append({input_name: x})
        self.iterator = iter(self.data)

    def get_next(self):
        return next(self.iterator, None)


def get_input_shape(model_input):
    dims = []
    for d in model_input.type.tensor_type.shape.dim:
        if d.dim_value > 0:
            dims.append(d.dim_value)
        else:
            dims.append(1)
    return dims


def quantize_onnx_model(input_model_path, output_model_path):
    with tempfile.NamedTemporaryFile(suffix=".onnx", delete=False) as f:
        preprocessed_model_path = f.name

    try:
        quant_pre_process(input_model_path, preprocessed_model_path)

        model = onnx.load(preprocessed_model_path)
        input_tensor = model.graph.input[0]
        input_name = input_tensor.name
        input_shape = get_input_shape(input_tensor)

        calib_reader = DummyCalibrationDataReader(
            input_name=input_name,
            input_shape=input_shape,
            num_samples=16,
        )

        quantize_static(
            model_input=preprocessed_model_path,
            model_output=output_model_path,
            calibration_data_reader=calib_reader,
            quant_format=QuantFormat.QDQ,
            activation_type=QuantType.QInt8,
            weight_type=QuantType.QInt8,
            per_channel=True,
        )
    finally:
        if os.path.exists(preprocessed_model_path):
            os.remove(preprocessed_model_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=str)
    parser.add_argument("output", type=str)
    args = parser.parse_args()
    quantize_onnx_model(input_model_path=args.input, output_model_path=args.output)
