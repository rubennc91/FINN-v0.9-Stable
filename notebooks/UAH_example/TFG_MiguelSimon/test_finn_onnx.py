# -*- coding: utf-8 -*-

import sys
import numpy as np

from PIL import Image

from qonnx.core.modelwrapper import ModelWrapper
from qonnx.core.onnx_exec import execute_onnx
from qonnx.transformation.infer_shapes import InferShapes

if len(sys.argv) < 3:
    print("Uso: python3 test_finn_onnx.py modelo.onnx imagen.png")
    sys.exit(1)

onnx_path = sys.argv[1]
img_path = sys.argv[2]

H = 16
W = 12

print("====================================")
print("Modelo:", onnx_path)
print("Imagen:", img_path)

model = ModelWrapper(onnx_path)
model = model.transform(InferShapes())

all_input_names = [i.name for i in model.graph.input]
output_names = [o.name for o in model.graph.output]

print("Entradas encontradas en el grafo:")
for name in all_input_names:
    try:
        shape = model.get_tensor_shape(name)
        dtype = model.get_tensor_datatype(name)
    except Exception:
        shape = "desconocida"
        dtype = "desconocido"
    print("  ", name, "shape =", shape, "dtype =", dtype)

print("Salidas del modelo:")
for name in output_names:
    try:
        shape = model.get_tensor_shape(name)
        dtype = model.get_tensor_datatype(name)
    except Exception:
        shape = "desconocida"
        dtype = "desconocido"
    print("  ", name, "shape =", shape, "dtype =", dtype)

candidate_inputs = []

for name in all_input_names:
    try:
        shape = model.get_tensor_shape(name)
    except Exception:
        continue

    if shape is None:
        continue

    if len(shape) == 2 and shape[1] == 576:
        candidate_inputs.append(name)

    elif len(shape) == 4 and shape[1] == 3 and shape[2] == 16 and shape[3] == 12:
        candidate_inputs.append(name)

if len(candidate_inputs) == 0:
    raise RuntimeError("No se ha encontrado una entrada compatible.")

input_name = candidate_inputs[0]
input_shape = model.get_tensor_shape(input_name)

print("====================================")
print("Input usado:", input_name)
print("Input shape usado:", input_shape)
print("====================================")

img = Image.open(img_path).convert("RGB")
img = img.resize((W, H))
img_np = np.array(img)

if len(input_shape) == 2:
    r = img_np[:, :, 0].flatten()
    g = img_np[:, :, 1].flatten()
    b = img_np[:, :, 2].flatten()

    x = np.concatenate([r, g, b]).astype(np.float32)
    x = x.reshape(input_shape)

elif len(input_shape) == 4:
    x = img_np.astype(np.float32)
    x = np.transpose(x, (2, 0, 1))
    x = x.reshape(input_shape)

else:
    raise RuntimeError("Forma de entrada no contemplada: {}".format(input_shape))

print("Primeros 20 valores de entrada:")
print(x.flatten()[:20])

print("Cambio R-G, posiciones 185 a 199:")
print(x.flatten()[185:200])

print("Cambio G-B, posiciones 377 a 391:")
print(x.flatten()[377:392])

input_dict = {
    input_name: x
}

print("====================================")
print("Ejecutando modelo con QONNX/FINN...")
output_dict = execute_onnx(model, input_dict)

print("Salida:")
for name in output_names:
    print("Output:", name)
    print("Shape:", output_dict[name].shape)
    print(output_dict[name])

print("====================================")
