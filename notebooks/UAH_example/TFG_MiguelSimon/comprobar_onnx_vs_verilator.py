import os
import csv
import numpy as np
from PIL import Image

from qonnx.core.modelwrapper import ModelWrapper
from qonnx.core.onnx_exec import execute_onnx

MODEL_PATH = "model_for_finn_w4a8_finetuned_uint8.onnx"

DATASET_DIR = "/home/miguel_tfg/FINN-v0.9-Stable/notebooks/UAH_example/output_final_miguel/Dataset_JdeRobot/DATA/counter_montmelo_holonomic"
CSV_PATH = os.path.join(DATASET_DIR, "data.csv")

V_MIN = -0.6
V_MAX = 13.0
PI = np.pi

def denorm_v_from_u8(raw):
    return V_MIN + (float(raw) / 255.0) * (V_MAX - V_MIN)

def denorm_w_from_u8(raw):
    return -PI + (float(raw) / 255.0) * (2.0 * PI)

def image_to_input(img_path, input_shape):
    img = Image.open(img_path).convert("RGB")
    img = img.resize((12, 16))

    arr = np.asarray(img).astype(np.float32)  # H,W,C = 16,12,3

    chw = np.transpose(arr, (2, 0, 1))        # C,H,W = 3,16,12
    flat = chw.reshape(-1)                    # RRR... GGG... BBB...

    if len(input_shape) == 4:
        return chw[None, :, :, :].astype(np.float32)
    elif len(input_shape) == 2:
        return flat[None, :].astype(np.float32)
    else:
        return flat.astype(np.float32).reshape(input_shape)

def read_csv_rows(csv_path):
    rows = []
    with open(csv_path, newline="") as f:
        reader = csv.reader(f)
        header = next(reader)
        for row in reader:
            if len(row) >= 3:
                rows.append(row)
    return rows

def find_image(i, row):
    candidates = [
        os.path.join(DATASET_DIR, f"{i+1}.png"),
        os.path.join(DATASET_DIR, f"{i}.png"),
    ]

    if len(row) > 0:
        candidates.append(os.path.join(DATASET_DIR, row[0]))
        candidates.append(os.path.join(DATASET_DIR, row[0] + ".png"))

    for c in candidates:
        if os.path.exists(c):
            return c

    return None

print("Modelo:", MODEL_PATH)

model = ModelWrapper(MODEL_PATH)
input_name = model.graph.input[0].name
output_name = model.graph.output[0].name
input_shape = model.get_tensor_shape(input_name)

print("Input:", input_name)
print("Output:", output_name)
print("Input shape:", input_shape)

rows = read_csv_rows(CSV_PATH)
print("Filas CSV:", len(rows))

with open("resultados_modelo_cuantizado.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow([
        "frame",
        "csv_v",
        "csv_w",
        "raw0",
        "raw1",
        "raw2",
        "v_raw0",
        "w_raw1",
        "output_flat"
    ])

    for i, row in enumerate(rows[:100]):
        v_csv = float(row[1])
        w_csv = float(row[2])

        img_path = find_image(i, row)
        if img_path is None:
            print("No encuentro imagen para frame", i)
            continue

        inp = image_to_input(img_path, input_shape)

        outputs = execute_onnx(model, {input_name: inp})
        y = outputs[output_name]
        y_flat = np.asarray(y).reshape(-1)

        # El modelo ONNX devuelve valores normalizados entre 0 y 1.
        # Para compararlo con Verilator, los pasamos a formato uint8: 0..255.
        raw0 = int(round(float(y_flat[0]) * 255.0)) if len(y_flat) > 0 else 0
        raw1 = int(round(float(y_flat[1]) * 255.0)) if len(y_flat) > 1 else 0
        raw2 = int(round(float(y_flat[2]) * 255.0)) if len(y_flat) > 2 else 0

        raw0 = max(0, min(255, raw0))
        raw1 = max(0, min(255, raw1))
        raw2 = max(0, min(255, raw2))

        v_onnx = denorm_v_from_u8(raw0)
        w_onnx = denorm_w_from_u8(raw1)

        writer.writerow([
            i,
            v_csv,
            w_csv,
            raw0,
            raw1,
            raw2,
            v_onnx,
            w_onnx,
            y_flat.tolist()
        ])

        print(
            f"Frame {i} | CSV v={v_csv} w={w_csv} "
            f"| ONNX raw0={raw0} raw1={raw1} raw2={raw2} "
            f"| ONNX v={v_onnx} w={w_onnx} "
            f"| salida={y_flat}"
        )

print("Guardado: resultados_modelo_cuantizado.csv")
