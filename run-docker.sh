#!/bin/bash
# FINN Docker Runner - Versión Vitaminada (Evita Kernel Crash)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

gecho () { echo -e "${GREEN}$1${NC}"; }
recho () { echo -e "${RED}$1${NC}"; }

# 1. VERIFICACIÓN
[ -z "$FINN_XILINX_PATH" ] || [ -z "$FINN_XILINX_VERSION" ] && recho "Error: Configura Xilinx Path y Version"

DOCKER_UNAME=$(id -un)
DOCKER_UID=$(id -u)
DOCKER_GID=$(id -g)
DOCKER_INST_NAME="finn_dev_${DOCKER_UNAME}"
SCRIPTPATH=$(readlink -f $(dirname "$0"))

# --- CONFIGURACIÓN DE RECURSOS ---
: ${JUPYTER_PORT=8898}
: ${NETRON_PORT=8082}
: ${NUM_DEFAULT_WORKERS=2} # Bajado de 4 a 2 para evitar saturar la RAM
FINAL_TAG="xilinx/finn:v0.9-dirty.xrt_202210.2.13.466_18.04-amd64-xrt"

# --- RUTAS ---
DEPS="$SCRIPTPATH/deps"
MY_PYTHONPATH="$SCRIPTPATH/src:$DEPS/qonnx/src:$DEPS/finn-experimental/src:$DEPS/brevitas/src:$DEPS/pyverilator"

INTERNAL_PATH="/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
if [ ! -z "$FINN_XILINX_PATH" ]; then
    V_PATH="$FINN_XILINX_PATH/Vivado/$FINN_XILINX_VERSION/bin"
    H_PATH="$FINN_XILINX_PATH/Vitis_HLS/$FINN_XILINX_VERSION/bin"
    INTERNAL_PATH="$V_PATH:$H_PATH:$INTERNAL_PATH"
fi

# 2. LANZAMIENTO VITAMINADO
docker run -t --rm --tty --init \
    --name "$DOCKER_INST_NAME" \
    --hostname "$DOCKER_INST_NAME" \
    --user "$DOCKER_UID:$DOCKER_GID" \
    --entrypoint /bin/bash \
    --shm-size=2g \
    --ulimit memlock=-1:-1 \
    --ulimit stack=67108864:67108864 \
    -w "$SCRIPTPATH" \
    -v "$SCRIPTPATH:$SCRIPTPATH" \
    -v "/tmp/$DOCKER_INST_NAME:/tmp/$DOCKER_INST_NAME" \
    -v "$FINN_XILINX_PATH:$FINN_XILINX_PATH" \
    -p "$JUPYTER_PORT:$JUPYTER_PORT" \
    -p "$NETRON_PORT:$NETRON_PORT" \
    -e "HOME=/tmp" \
    -e "FINN_ROOT=$SCRIPTPATH" \
    -e "NUM_DEFAULT_WORKERS=$NUM_DEFAULT_WORKERS" \
    "$FINAL_TAG" -c "
        export PYTHONPATH=$MY_PYTHONPATH
        export PATH=$INTERNAL_PATH
        jupyter notebook --allow-root --no-browser --ip=0.0.0.0 --port $JUPYTER_PORT notebooks
    "