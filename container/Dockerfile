FROM osrf/ros:jazzy-desktop

# Noninteractive apt
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------
# 1) Basic tools + build tools
# ------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    tar \
    git \
    git-lfs \
    build-essential \
    cmake \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    lsb-release \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# 2) Isaac ROS APT repo (for ros-jazzy-isaac-ros-examples, realsense)
# ------------------------------------------------------------------
RUN curl -sL https://isaac.download.nvidia.com/isaac-ros/repos.key | apt-key add - && \
    sh -c 'echo "deb https://isaac.download.nvidia.com/isaac-ros/ubuntu/main $(lsb_release -cs) main" > /etc/apt/sources.list.d/isaac-ros.list' && \
    apt-get update

# Install examples + RealSense binary packages
RUN apt-get install -y \
    ros-jazzy-isaac-ros-examples \
    ros-jazzy-isaac-ros-realsense \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# 3) (Optional but recommended) TensorRT user-space tools
# ------------------------------------------------------------------
# NOTE: You still need TensorRT in the container image; adjust as needed.
# This line is deliberately commented because exact package names depend
# on your CUDA/TensorRT repo. Uncomment & adapt once your CUDA repo is set.
#
# RUN apt-get update && apt-get install -y tensorrt && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------
# 4) Workspace layout + ENV
# ------------------------------------------------------------------
# Use same workspace name as Isaac ROS docs
ENV ISAAC_ROS_WS=/workspaces/isaac_ros-dev

RUN mkdir -p ${ISAAC_ROS_WS}/src

# Make sure ROS & workspace are always sourced and ISAAC_ROS_WS is exported
RUN echo "export ISAAC_ROS_WS=${ISAAC_ROS_WS}" >> /root/.bashrc && \
    echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc && \
    echo 'if [ -f "${ISAAC_ROS_WS}/install/setup.bash" ]; then source "${ISAAC_ROS_WS}/install/setup.bash"; fi' >> /root/.bashrc

# ------------------------------------------------------------------
# 5) Provide a tiny 'isaac-ros activate' shim for convenience
# ------------------------------------------------------------------
RUN printf '#!/usr/bin/env bash\n'                            >  /usr/local/bin/isaac-ros && \
    printf 'export ISAAC_ROS_WS=${ISAAC_ROS_WS:-/workspaces/isaac_ros-dev}\n' >> /usr/local/bin/isaac-ros && \
    printf 'source /opt/ros/jazzy/setup.bash\n'               >> /usr/local/bin/isaac-ros && \
    printf 'if [ -f "$ISAAC_ROS_WS/install/setup.bash" ]; then\n' >> /usr/local/bin/isaac-ros && \
    printf '  source "$ISAAC_ROS_WS/install/setup.bash"\n'    >> /usr/local/bin/isaac-ros && \
    printf 'fi\n'                                             >> /usr/local/bin/isaac-ros && \
    printf 'cd "$ISAAC_ROS_WS"\n'                             >> /usr/local/bin/isaac-ros && \
    printf 'exec bash\n'                                      >> /usr/local/bin/isaac-ros && \
    chmod +x /usr/local/bin/isaac-ros

# ------------------------------------------------------------------
# 6) Copy helper scripts into image
# ------------------------------------------------------------------
WORKDIR /root
COPY foundationpose_setup.sh /root/foundationpose_setup.sh
COPY run_foundationpose_realsense.sh /root/run_foundationpose_realsense.sh
RUN chmod +x /root/foundationpose_setup.sh /root/run_foundationpose_realsense.sh

WORKDIR ${ISAAC_ROS_WS}

# Default: just drop into a bash shell
CMD ["bash"]
