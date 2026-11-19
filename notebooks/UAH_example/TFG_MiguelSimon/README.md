# TFG de Miguel Simón: cuantización y compilación con FINN

Notebooks, scripts y modelos del TFG de Miguel Simón (red neuronal para el control de un vehículo F1 en Montmeló, sobre FPGA). Todo corre dentro del contenedor de FINN v0.9 (`./run-docker.sh notebook` desde la raíz de este repositorio), con esta carpeta como directorio de trabajo. Las rutas son relativas a ella.

El resto del proyecto (simulación con Verilator, ROS 2/Gazebo, dataset, entrenamiento original) está en
**https://github.com/rubennc91/TFG_MiguelSimon_2026**.

## Flujo, en orden
| Paso | Fichero | Qué hace |
|---|---|---|
| 1 | `mlp_27k.ckpt`, `state_dict_quantized_last.pth` | Pesos de partida (entrenamiento en el repositorio del TFG, `01_entrenamiento/`). |
| 2 | `Quantize_MLP27K_Montmelo_FINN.ipynb` y `_v2`, `_v3_finetuning*`, `_v4_*` | Cuantización W4A8 con Brevitas y exportación a ONNX. **`Quantize_MLP27K_Montmelo_FINN_v4_clean_rebuild_verilator.ipynb` es el notebook DEFINITIVO** (confirmado por el tutor); es el flujo limpio y genera `q_mlp27k_w4a8_finetuned.pth` y los ONNX. |
| 3 | `model_tidy.onnx`, `folding_config_miguel.json` | Modelo ordenado y plegado para FINN. |
| 4 | `build_miguel.py` o `FINN_build_MLP27K_W4A8_finetuned_minimal.ipynb` | Compilación con FINN a IP en `xc7z020clg400-1`, 10 ns, 1000 fps. |
| 5 | `comprobar_onnx_vs_verilator.py`, `test_onnx.py`, `test_finn_onnx.py` | Comprobación del ONNX frente a la simulación en Verilator. |

La salida del build (`output_rebuild_mlp27k_w4a8_ft_clean/`) y la simulación con Verilator están en el repositorio del TFG, en `03_simulacion_verilator/`.

## Otros ficheros
- `Custom_dataflow_QNN_Miguel_16x12_RGB*.ipynb`, `Custom_dataflow_MLP27K_Montmelo.ipynb`: flujos con el dataflow personalizado.
- `*.onnx`: modelos de cada etapa (`mlp27k_clean`, `model_for_finn_*`, `mlp27k_w4a8_finetuned`, `preproc_div255_*`, `debug_step_*`).
- `output_final_miguel/`, `output_final_mlp27k/`: informes y logs de otras compilaciones (sin ficheros generados).
- `resultados_modelo_cuantizado.csv`: resultados de la cuantización.
- `versiones_sin_salidas/`: copias de los notebooks sin las salidas de las celdas.

## Autoría y licencia

© 2026 Miguel Simón Chica y Rubén Nieto Capuchino (tutor). Código bajo MIT y documentación bajo CC BY 4.0 (ver el repositorio del TFG). El resto de FINN conserva su licencia BSD-3.
