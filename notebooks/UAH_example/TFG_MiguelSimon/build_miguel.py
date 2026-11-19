
import os
import shutil

from finn.builder import build_dataflow as build
from finn.builder import build_dataflow_config as build_cfg

MODEL_TIDY_ONNX = "model_tidy.onnx"
FINAL_OUTPUT_DIR = "output_final_miguel"
FOLDING_FILE = "folding_config_miguel.json"
FPGA_PART = "xc7z020clg400-1"

if os.path.exists(FINAL_OUTPUT_DIR):
    shutil.rmtree(FINAL_OUTPUT_DIR)

cfg = build.DataflowBuildConfig(
    output_dir=FINAL_OUTPUT_DIR,
    generate_outputs=[
        build_cfg.DataflowOutputType.ESTIMATE_REPORTS,
        build_cfg.DataflowOutputType.STITCHED_IP,
    ],
    folding_config_file=FOLDING_FILE,
    auto_fifo_depths=True,
    mvau_wwidth_max=36,
    target_fps=1000,
    synth_clk_period_ns=10.0,
    fpga_part=FPGA_PART
)

build.build_dataflow_cfg(MODEL_TIDY_ONNX, cfg)
print("Build finalizado. Revisa:", FINAL_OUTPUT_DIR)
