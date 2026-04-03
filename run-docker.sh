#!/bin/bash
# Copyright (c) 2020-2022, Xilinx, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of FINN nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# green echo
gecho () {
  echo -e "${GREEN}$1${NC}"
}

# red echo
recho () {
  echo -e "${RED}$1${NC}"
}

if [ -z "$FINN_XILINX_PATH" ];then
  recho "Please set the FINN_XILINX_PATH environment variable to the path to your Xilinx tools installation directory (e.g. /opt/Xilinx)."
  recho "FINN functionality depending on Vivado, Vitis or HLS will not be available."
fi

if [ -z "$FINN_XILINX_VERSION" ];then
  recho "Please set the FINN_XILINX_VERSION to the version of the Xilinx tools to use (e.g. 2020.1)"
  recho "FINN functionality depending on Vivado, Vitis or HLS will not be available."
fi

if [ -z "$PLATFORM_REPO_PATHS" ];then
  recho "Please set PLATFORM_REPO_PATHS pointing to Vitis platform files (DSAs)."
  recho "This is required to be able to use Alveo PCIe cards."
fi

DOCKER_GID=$(id -g)
DOCKER_GNAME=$(id -gn)
DOCKER_UNAME=$(id -un)
DOCKER_UID=$(id -u)
DOCKER_PASSWD="finn"
DOCKER_INST_NAME="finn_dev_${DOCKER_UNAME}"
# ensure Docker inst. name is all lowercase
DOCKER_INST_NAME=$(echo "$DOCKER_INST_NAME" | tr '[:upper:]' '[:lower:]')
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")

# the settings below will be taken from environment variables if available,
# otherwise the defaults below will be used
: ${JUPYTER_PORT=8898}
: ${JUPYTER_PASSWD_HASH=""}
: ${NETRON_PORT=8082}
: ${LOCALHOST_URL="localhost"}
: ${PYNQ_USERNAME="xilinx"}
: ${PYNQ_PASSWORD="xilinx"}
: ${PYNQ_BOARD="Pynq-Z1"}
: ${PYNQ_TARGET_DIR="/home/xilinx/$DOCKER_INST_NAME"}
: ${NUM_DEFAULT_WORKERS=4}
: ${FINN_SSH_KEY_DIR="$SCRIPTPATH/ssh_keys"}
: ${ALVEO_USERNAME="alveo_user"}
: ${ALVEO_PASSWORD=""}
: ${ALVEO_BOARD="U250"}
: ${ALVEO_TARGET_DIR="/tmp"}
: ${PLATFORM_REPO_PATHS="/opt/xilinx/platforms"}
: ${XRT_DEB_VERSION="xrt_202210.2.13.466_18.04-amd64-xrt"}
: ${FINN_HOST_BUILD_DIR="/tmp/$DOCKER_INST_NAME"}
: ${FINN_DOCKER_TAG="xilinx/finn:$(git describe --always --tags --dirty).$XRT_DEB_VERSION"}
: ${FINN_DOCKER_PREBUILT="0"}
: ${FINN_DOCKER_RUN_AS_ROOT="0"}
: ${FINN_DOCKER_GPU="$(docker info | grep nvidia | wc -m)"}
: ${FINN_DOCKER_EXTRA=""}
: ${FINN_SKIP_DEP_REPOS="0"}
: ${OHMYXILINX="${SCRIPTPATH}/deps/oh-my-xilinx"}
: ${NVIDIA_VISIBLE_DEVICES=""}
: ${DOCKER_BUILDKIT="1"}

DOCKER_INTERACTIVE=""

if [ "$1" = "test" ]; then
  gecho "Running test suite (all tests)"
  DOCKER_CMD="python setup.py test"
elif [ "$1" = "quicktest" ]; then
  gecho "Running test suite (non-Vivado, non-slow tests)"
  DOCKER_CMD="quicktest.sh"
elif [ "$1" = "notebook" ]; then
  gecho "Running Jupyter notebook server"
  if [ -z "$JUPYTER_PASSWD_HASH" ]; then
    JUPYTER_PASSWD_ARG=""
  else
    JUPYTER_PASSWD_ARG="--NotebookApp.password='$JUPYTER_PASSWD_HASH'"
  fi
  DOCKER_CMD="jupyter notebook --allow-root --no-browser --ip=0.0.0.0 --port $JUPYTER_PORT $JUPYTER_PASSWD_ARG notebooks"
  FINN_DOCKER_EXTRA+="-e JUPYTER_PORT=$JUPYTER_PORT "
  FINN_DOCKER_EXTRA+="-e NETRON_PORT=$NETRON_PORT "
  FINN_DOCKER_EXTRA+="-p $JUPYTER_PORT:$JUPYTER_PORT "
  FINN_DOCKER_EXTRA+="-p $NETRON_PORT:$NETRON_PORT "
elif [ "$1" = "build_dataflow" ]; then
  BUILD_DATAFLOW_DIR=$(readlink -f "$2")
  FINN_DOCKER_EXTRA+="-v $BUILD_DATAFLOW_DIR:$BUILD_DATAFLOW_DIR "
  DOCKER_INTERACTIVE="-it"
  #FINN_HOST_BUILD_DIR=$BUILD_DATAFLOW_DIR/build
  gecho "Running build_dataflow for folder $BUILD_DATAFLOW_DIR"
  DOCKER_CMD="build_dataflow $BUILD_DATAFLOW_DIR"
elif [ "$1" = "build_custom" ]; then
  BUILD_CUSTOM_DIR=$(readlink -f "$2")
  FLOW_NAME=${3:-build}
  FINN_DOCKER_EXTRA+="-v $BUILD_CUSTOM_DIR:$BUILD_CUSTOM_DIR -w $BUILD_CUSTOM_DIR "
  DOCKER_INTERACTIVE="-it"
  #FINN_HOST_BUILD_DIR=$BUILD_DATAFLOW_DIR/build
  gecho "Running build_custom: $BUILD_CUSTOM_DIR/$FLOW_NAME.py"
  DOCKER_CMD="python -mpdb -cc -cq $FLOW_NAME.py"
elif [ -z "$1" ]; then
   gecho "Running container only"
   DOCKER_CMD="bash"
   DOCKER_INTERACTIVE="-it"
else
  gecho "Running container with passed arguments"
  DOCKER_CMD="$@"
fi


if [ "$FINN_DOCKER_GPU" != 0 ];then
  gecho "nvidia-docker detected, enabling GPUs"
  if [ ! -z "$NVIDIA_VISIBLE_DEVICES" ];then
    FINN_DOCKER_EXTRA+="--runtime nvidia -e NVIDIA_VISIBLE_DEVICES=$NVIDIA_VISIBLE_DEVICES "
  else
    FINN_DOCKER_EXTRA+="--gpus all "
  fi
fi

VIVADO_HLS_LOCAL=$VIVADO_PATH
VIVADO_IP_CACHE=$FINN_HOST_BUILD_DIR/vivado_ip_cache

# ensure build dir exists locally
mkdir -p $FINN_HOST_BUILD_DIR
mkdir -p $FINN_SSH_KEY_DIR

gecho "Docker container is named $DOCKER_INST_NAME"
gecho "Docker tag is named $FINN_DOCKER_TAG"
gecho "Mounting $FINN_HOST_BUILD_DIR into $FINN_HOST_BUILD_DIR"
gecho "Mounting $FINN_XILINX_PATH into $FINN_XILINX_PATH"
gecho "Port-forwarding for Jupyter $JUPYTER_PORT:$JUPYTER_PORT"
gecho "Port-forwarding for Netron $NETRON_PORT:$NETRON_PORT"
gecho "Vivado IP cache dir is at $VIVADO_IP_CACHE"
gecho "Using default PYNQ board $PYNQ_BOARD"

# Ensure git-based deps are checked out at correct commit
if [ "$FINN_SKIP_DEP_REPOS" = "0" ]; then
  ./fetch-repos.sh
fi

# Build the FINN Docker image
if [ "$FINN_DOCKER_PREBUILT" = "0" ]; then
  # Need to ensure this is done within the finn/ root folder:
  OLD_PWD=$(pwd)
  cd $SCRIPTPATH
  docker build -f docker/Dockerfile.finn --build-arg XRT_DEB_VERSION=$XRT_DEB_VERSION --tag=$FINN_DOCKER_TAG .
  cd $OLD_PWD
fi
# Launch container with current directory mounted
# ==============================================================================
# BLOQUE DE LANZAMIENTO SEGURO (CON PATH DE CONDA Y XILINX)
# ==============================================================================

# 1. DEFINIR EL TAG (Asegúrate de que coincide con el de 'docker images')
FINAL_TAG="xilinx/finn:5762f54-dirty.xrt_202210.2.13.466_18.04-amd64-xrt"

# 2. CONFIGURAR EL PATH INTERNO (Inyectando Xilinx y manteniendo Conda)
# Añadimos /opt/conda/bin que es donde vive Jupyter y Pip en esta imagen
INTERNAL_PATH="/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if [ ! -z "$FINN_XILINX_PATH" ]; then
    VIVADO_PATH="$FINN_XILINX_PATH/Vivado/$FINN_XILINX_VERSION"
    HLS_PATH="$FINN_XILINX_PATH/Vitis_HLS/$FINN_XILINX_VERSION"
    
    # Añadimos los bins de Xilinx al principio del PATH
    if [ -d "$HLS_PATH/bin" ]; then
        INTERNAL_PATH="$HLS_PATH/bin:$INTERNAL_PATH"
    fi
    if [ -d "$VIVADO_PATH/bin" ]; then
        INTERNAL_PATH="$VIVADO_PATH/bin:$INTERNAL_PATH"
    fi
fi

# 3. INICIALIZAR EL ARRAY DE ARGUMENTOS DE DOCKER
DOCKER_RUN_CMD=(docker run -t --rm --tty --init)

if [ ! -z "$DOCKER_INTERACTIVE" ]; then
    DOCKER_RUN_CMD+=($DOCKER_INTERACTIVE)
fi

# 4. AÑADIR VARIABLES DE ENTORNO Y VOLÚMENES
# Importante: mantenemos PYTHONPATH para que encuentre tus librerías locales
DOCKER_RUN_CMD+=(
    --hostname "$DOCKER_INST_NAME"
    -e "SHELL=/bin/bash"
    -w "$SCRIPTPATH"
    -v "$SCRIPTPATH:$SCRIPTPATH"
    -v "$FINN_HOST_BUILD_DIR:$FINN_HOST_BUILD_DIR"
    -v "$FINN_XILINX_PATH:$FINN_XILINX_PATH"
    -e "FINN_BUILD_DIR=$FINN_HOST_BUILD_DIR"
    -e "FINN_ROOT=$SCRIPTPATH"
    -e "XILINX_VIVADO=$VIVADO_PATH"
    -e "VIVADO_PATH=$VIVADO_PATH"
    -e "HLS_PATH=$HLS_PATH"
    -e "PATH=$INTERNAL_PATH"
    -e "PYTHONPATH=$SCRIPTPATH/src:$SCRIPTPATH/deps/qonnx/src:$SCRIPTPATH/deps/brevitas:$SCRIPTPATH/deps/finn-experimental/src"
    -e "LOCALHOST_URL=$LOCALHOST_URL"
    -e "NUM_DEFAULT_WORKERS=$NUM_DEFAULT_WORKERS"
)

# 5. PUERTOS JUPYTER / NETRON
if [ "$1" = "notebook" ]; then
    DOCKER_RUN_CMD+=(
        -e "JUPYTER_PORT=$JUPYTER_PORT"
        -e "NETRON_PORT=$NETRON_PORT"
        -p "$JUPYTER_PORT:$JUPYTER_PORT"
        -p "$NETRON_PORT:$NETRON_PORT"
    )
fi

# 6. CONFIGURACIÓN DE USUARIO (Si no es root)
if [ "$FINN_DOCKER_RUN_AS_ROOT" = "0" ]; then
    DOCKER_RUN_CMD+=(
        -v "/etc/group:/etc/group:ro"
        -v "/etc/passwd:/etc/passwd:ro"
        -v "/etc/shadow:/etc/shadow:ro"
        -v "/etc/sudoers.d:/etc/sudoers.d:ro"
        --user "$DOCKER_UID:$DOCKER_GID"
    )
fi

# MENSAJE DE ESTADO
gecho "-------------------------------------------------------"
gecho "Lanzando FINN..."
gecho "PATH corregido: $INTERNAL_PATH"
gecho "-------------------------------------------------------"

# 7. EJECUCIÓN FINAL
"${DOCKER_RUN_CMD[@]}" "$FINAL_TAG" $DOCKER_CMD