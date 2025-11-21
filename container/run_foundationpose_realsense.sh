#!/usr/bin/env bash
set -euo pipefail

export ISAAC_ROS_WS=${ISAAC_ROS_WS:-/workspaces/isaac_ros-dev}
source /opt/ros/jazzy/setup.bash

# If the workspace was built, source it
if [ -f "${ISAAC_ROS_WS}/install/setup.bash" ]; then
    source "${ISAAC_ROS_WS}/install/setup.bash"
fi

# Make sure the example deps are installed (idempotent)
apt-get update
apt-get install -y \
    ros-jazzy-isaac-ros-examples \
    ros-jazzy-isaac-ros-realsense

# Paths from the NVIDIA quickstart (edit mesh path as needed)
MESH_PATH="${ISAAC_ROS_WS}/isaac_ros_assets/isaac_ros_foundationpose/Mac_and_cheese_0_1/Mac_and_cheese_0_1.obj"
SCORE_ENGINE="${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose/score_trt_engine.plan"
REFINE_ENGINE="${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose/refine_trt_engine.plan"
RT_DETR_ENGINE="${ISAAC_ROS_WS}/isaac_ros_assets/models/synthetica_detr/sdetr_grasp.plan"

echo "Using:"
echo "  MESH_PATH       = ${MESH_PATH}"
echo "  SCORE_ENGINE    = ${SCORE_ENGINE}"
echo "  REFINE_ENGINE   = ${REFINE_ENGINE}"
echo "  RT_DETR_ENGINE  = ${RT_DETR_ENGINE}"

# Launch the RealSense + FoundationPose example
ros2 launch isaac_ros_examples isaac_ros_examples.launch.py \
    launch_fragments:=realsense_mono_rect_depth,foundationpose \
    mesh_file_path:="${MESH_PATH}" \
    score_engine_file_path:="${SCORE_ENGINE}" \
    refine_engine_file_path:="${REFINE_ENGINE}" \
    rt_detr_engine_file_path:="${RT_DETR_ENGINE}"
