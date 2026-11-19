import onnxruntime as ort
import numpy as np
import cv2
import sys

if len(sys.argv) < 3:
    print("Uso: python3 test_onnx.py modelo.onnx imagen.png")
    sys.exit(1)

onnx_path = sys.argv[1]
img_path = sys.argv[2]

H = 16
W = 12

img = cv2.imread(img_path)

if img is None:
    raise RuntimeError(f"No se puede leer la imagen: {img_path}")

img = cv2.resize(img, (W, H))
img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

session = ort.InferenceSession(onnx_path)

input_name = session.get_inputs()[0].name
input_shape = session.get_inputs()[0].shape
input_type = session.get_inputs()[0].type
output_names = [o.name for o in session.get_outputs()]

print("====================================")
print("Modelo:", onnx_path)
print("Imagen:", img_path)
print("Input name:", input_name)
print("Input shape:", input_shape)
print("Input type:", input_type)
print("Output names:", output_names)
print("====================================")

if len(input_shape) == 2:
    r = img[:, :, 0].flatten()
    g = img[:, :, 1].flatten()
    b = img[:, :, 2].flatten()

    x = np.concatenate([r, g, b]).astype(np.float32)
    x = x.reshape(1, 576)

elif len(input_shape) == 4:
    x = img.astype(np.float32)
    x = np.transpose(x, (2, 0, 1))
    x = x.reshape(1, 3, 16, 12)

else:
    raise RuntimeError(f"Forma de entrada no contemplada: {input_shape}")

print("Primeros 20 valores de entrada:")
print(x.flatten()[:20])

print("Cambio R-G, posiciones 185 a 199:")
print(x.flatten()[185:200])

print("Cambio G-B, posiciones 377 a 391:")
print(x.flatten()[377:392])

outputs = session.run(output_names, {input_name: x})

print("====================================")
print("Salida ONNX:")
for i, out in enumerate(outputs):
    print(f"Output {i}: shape = {out.shape}")
    print(out)
print("====================================")
