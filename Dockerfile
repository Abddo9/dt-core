# parameters
ARG REPO_NAME="dt-core"
ARG DESCRIPTION="Provides high-level autonomy and fleet-coordination capabilities"
ARG MAINTAINER="Andrea F. Daniele (afdaniele@duckietown.com)"
# pick an icon from: https://fontawesome.com/v4.7.0/icons/
ARG ICON="diamond"

# ==================================================>
# ==> Do not change the code below this line
ARG ARCH=arm64v8
ARG DISTRO=daffy
ARG DOCKER_REGISTRY=docker.io
ARG BASE_IMAGE=dt-ros-commons
ARG BASE_TAG=${DISTRO}-${ARCH}
ARG LAUNCHER=default
# #! ADDED FOR ML PIPELINE:
ARG CUDA_VERSION=10.2

# define base image
FROM ${DOCKER_REGISTRY}/duckietown/${BASE_IMAGE}:${BASE_TAG} as base

# recall all arguments
ARG DISTRO
ARG REPO_NAME
ARG DESCRIPTION
ARG MAINTAINER
ARG ICON
ARG BASE_TAG
ARG BASE_IMAGE
ARG LAUNCHER
# - buildkit
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
#! ADDED FOR ML PIPELINE:
ARG CUDA_VERSION

# check build arguments
RUN dt-build-env-check "${REPO_NAME}" "${MAINTAINER}" "${DESCRIPTION}"

# define/create repository path
ARG REPO_PATH="${CATKIN_WS_DIR}/src/${REPO_NAME}"
ARG LAUNCH_PATH="${LAUNCH_DIR}/${REPO_NAME}"
RUN mkdir -p "${REPO_PATH}" "${LAUNCH_PATH}"
WORKDIR "${REPO_PATH}"

# keep some arguments as environment variables
ENV DT_MODULE_TYPE="${REPO_NAME}" \
    DT_MODULE_DESCRIPTION="${DESCRIPTION}" \
    DT_MODULE_ICON="${ICON}" \
    DT_MAINTAINER="${MAINTAINER}" \
    DT_REPO_PATH="${REPO_PATH}" \
    DT_LAUNCH_PATH="${LAUNCH_PATH}" \
    DT_LAUNCHER="${LAUNCHER}"


#! ADDED FOR ML PIPELINE: add cuda to path
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

#! ADDED FOR ML PIPELINE: nvidia-container-runtime
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/user-guide.html
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES all

#! ADDED FOR ML PIPELINE: add cuda to path
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

#! ADDED FOR ML PIPELINE: nvidia-container-runtime
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/user-guide.html
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES all

# install apt dependencies
COPY ./dependencies-apt.txt "${REPO_PATH}/"
RUN dt-apt-install ${REPO_PATH}/dependencies-apt.txt

# install opencv
COPY ./assets/opencv/${TARGETARCH} /tmp/opencv
RUN /tmp/opencv/install.sh && python3 -m pip list | grep opencv

#! ADDED FOR ML PIPELINE: versionning config
ENV CUDA_VERSION 10.2.89
ENV CUDA_PKG_VERSION 10-2=$CUDA_VERSION-1
ENV NCCL_VERSION 2.8.4
ENV CUDNN_VERSION 8.1.1.33
ENV PYTORCH_VERSION 1.7.0
ENV PYTORCHVISION_VERSION 0.8.0a0+2f40a48
ENV TENSORRT_VERSION 7.1.3.4
ENV PYCUDA_VERSION 2021.1

#! ADDED FOR ML PIPELINE: Symbolic Link:
RUN ln -s /usr/local/cuda-10.2 /usr/local/cuda

# #! ML PIPELINE: Download YOLOv5 model (weights will be downloaded from DCSS)
# RUN git clone -b v7.0 https://github.com/ultralytics/yolov5 "/yolov5"

# install python3 dependencies
ARG PIP_INDEX_URL="https://pypi.org/simple/"
ENV PIP_INDEX_URL=${PIP_INDEX_URL}
COPY ./dependencies-py3.* "${REPO_PATH}/"
RUN dt-pip3-install "${REPO_PATH}/dependencies-py3.*"

# #! ADDED FOR ML PIPELINE: install ML related stuff
RUN echo "${ARCH}"
COPY assets/arm64v8 "${REPO_PATH}/install"
RUN "${REPO_PATH}/install/install.sh"


#! install Zuper dependencies
ARG PIP_INDEX_URL="https://pypi.org/simple/"
ENV PIP_INDEX_URL=${PIP_INDEX_URL}
COPY ./requirements.txt "${REPO_PATH}/"
RUN python3 -m pip install  -r ${REPO_PATH}/requirements.txt

# copy the source code
COPY ./packages "${REPO_PATH}/packages"

# build packages
RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
  catkin build \
    --workspace ${CATKIN_WS_DIR}/

# install launcher scripts
COPY ./launchers/. "${LAUNCH_PATH}/"
RUN dt-install-launchers "${LAUNCH_PATH}"

# define default command
CMD ["bash", "-c", "dt-launcher-${DT_LAUNCHER}"]

# store module metadata
LABEL org.duckietown.label.module.type="${REPO_NAME}" \
    org.duckietown.label.module.description="${DESCRIPTION}" \
    org.duckietown.label.module.icon="${ICON}" \
    org.duckietown.label.platform.os="${TARGETOS}" \
    org.duckietown.label.platform.architecture="${TARGETARCH}" \
    org.duckietown.label.platform.variant="${TARGETVARIANT}" \
    org.duckietown.label.code.location="${REPO_PATH}" \
    org.duckietown.label.code.version.distro="${DISTRO}" \
    org.duckietown.label.base.image="${BASE_IMAGE}" \
    org.duckietown.label.base.tag="${BASE_TAG}" \
    org.duckietown.label.maintainer="${MAINTAINER}"
# <== Do not change the code above this line
# <==================================================

ENV DUCKIETOWN_ROOT="${SOURCE_DIR}"
# used for downloads
ENV DUCKIETOWN_DATA="/tmp/duckietown-data"
RUN echo 'config echo 1' > .compmake.rc

COPY scripts/send-fsm-state.sh /usr/local/bin
