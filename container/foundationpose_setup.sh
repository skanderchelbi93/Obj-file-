#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# Assumes you are running INSIDE the container.
# This script:
#   - exports ISAAC_ROS_WS
#   - downloads quickstart assets from NGC
#   - downloads FoundationPose ONNX models
#   - clones isaac_ros_pose_estimation (release-4.0)
#   - runs rosdep + colcon build
#   - runs TensorRT conversion (trtexec) for refine/score models
# ------------------------------------------------------------------

export ISAAC_ROS_WS=${ISAAC_ROS_WS:-/workspaces/isaac_ros-dev}
mkdir -p "${ISAAC_ROS_WS}"
cd "${ISAAC_ROS_WS}"

echo "Using ISAAC_ROS_WS=${ISAAC_ROS_WS}"

# Make sure ROS env is sourced (in case you run script directly)
source /opt/ros/jazzy/setup.bash

# --------------------------
# 1) Basic deps
# --------------------------
apt-get update
apt-get install -y curl jq tar git-lfs
git lfs install

# --------------------------
# 2) Download quickstart assets from NGC
# --------------------------
NGC_ORG="nvidia"
NGC_TEAM="isaac"
PACKAGE_NAME="isaac_ros_foundationpose"
NGC_RESOURCE="isaac_ros_foundationpose_assets"
NGC_FILENAME="quickstart.tar.gz"
MAJOR_VERSION=4
MINOR_VERSION=0

VERSION_REQ_URL="https://catalog.ngc.nvidia.com/api/resources/versions?orgName=$NGC_ORG&teamName=$NGC_TEAM&name=$NGC_RESOURCE&isPublic=true&pageNumber=0&pageSize=100&sortOrder=CREATED_DATE_DESC"

echo "Querying NGC for latest FoundationPose assets compatible with Isaac ROS ${MAJOR_VERSION}.${MINOR_VERSION}..."
AVAILABLE_VERSIONS=$(curl -s -H "Accept: application/json" "$VERSION_REQ_URL")

LATEST_VERSION_ID=$(echo "$AVAILABLE_VERSIONS" | jq -r "
    .recipeVersions[]
    | .versionId as \$v
    | \$v | select(test(\"^\\\\d+\\\\.\\\\d+\\\\.\\\\d+$\"))    # keep semantic versions
    | split(\".\") | {major: .[0]|tonumber, minor: .[1]|tonumber, patch: .[2]|tonumber, v: \"\(. [0]).\(. [1]).\(. [2])\"}
    | select(.major == $MAJOR_VERSION and .minor <= $MINOR_VERSION)
    | .v
    " | sort -V | tail -n 1)

if [ -z "$LATEST_VERSION_ID" ] || [ "$LATEST_VERSION_ID" = "null" ]; then
    echo "No corresponding version found for Isaac ROS $MAJOR_VERSION.$MINOR_VERSION"
    echo "Found versions:"
    echo "$AVAILABLE_VERSIONS" | jq -r '.recipeVersions[].versionId'
    exit 1
fi

echo "Using NGC asset version: $LATEST_VERSION_ID"

mkdir -p "${ISAAC_ROS_WS}/isaac_ros_assets"
FILE_REQ_URL="https://api.ngc.nvidia.com/v2/resources/$NGC_ORG/$NGC_TEAM/$NGC_RESOURCE/versions/$LATEST_VERSION_ID/files/$NGC_FILENAME"

echo "Downloading $NGC_FILENAME from NGC..."
curl -LO --request GET "${FILE_REQ_URL}"

echo "Extracting quickstart assets..."
tar -xf "${NGC_FILENAME}" -C "${ISAAC_ROS_WS}/isaac_ros_assets"
rm "${NGC_FILENAME}"

# --------------------------
# 3) Download FoundationPose ONNX models from NGC
# --------------------------
echo "Downloading FoundationPose ONNX models..."

mkdir -p "${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose"
cd "${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose"

wget 'https://api.ngc.nvidia.com/v2/models/nvidia/isaac/foundationpose/versions/1.0.1_onnx/files/refine_model.onnx' -O refine_model.onnx
wget 'https://api.ngc.nvidia.com/v2/models/nvidia/isaac/foundationpose/versions/1.0.1_onnx/files/score_model.onnx' -O score_model.onnx

# --------------------------
# 4) Clone isaac_ros_pose_estimation (release-4.0)
# --------------------------
cd "${ISAAC_ROS_WS}/src"

if [ ! -d "isaac_ros_pose_estimation" ]; then
    echo "Cloning isaac_ros_pose_estimation (release-4.0)..."
    git clone -b release-4.0 https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_pose_estimation.git isaac_ros_pose_estimation
else
    echo "isaac_ros_pose_estimation already cloned, skipping."
fi

# --------------------------
# 5) rosdep install
# --------------------------
cd "${ISAAC_ROS_WS}"

# Initialize rosdep if not already done
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    rosdep init || true
fi
rosdep update

echo "Installing dependencies with rosdep..."
rosdep install \
  --from-paths "${ISAAC_ROS_WS}/src/isaac_ros_pose_estimation/isaac_ros_foundationpose" \
  --ignore-src -y

# --------------------------
# 6) Build isaac_ros_foundationpose
# --------------------------
echo "Building isaac_ros_foundationpose..."
cd "${ISAAC_ROS_WS}"

colcon build \
  --symlink-install \
  --packages-up-to isaac_ros_foundationpose \
  --base-paths "${ISAAC_ROS_WS}/src/isaac_ros_pose_estimation/isaac_ros_foundationpose"

# Re-source the newly built workspace
echo "Sourcing built workspace..."
source "${ISAAC_ROS_WS}/install/setup.bash"

# --------------------------
# 7) Convert ONNX to TensorRT engines using trtexec
# --------------------------
echo "Converting ONNX models to TensorRT engine plans..."

if [ ! -x "/usr/src/tensorrt/bin/trtexec" ]; then
    echo "ERROR: /usr/src/tensorrt/bin/trtexec not found."
    echo "Please make sure TensorRT is installed in the container and trtexec is available."
    exit 1
fi

cd "${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose"

# Refine model
/usr/src/tensorrt/bin/trtexec \
    --onnx="${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose/refine_model.onnx" \
    --saveEngine="${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose/refine_trt_engine.plan" \
    --minShapes=input1:1x160x160x6,input2:1x160x160x6 \
    --optShapes=input1:1x160x160x6,input2:1x160x160x6 \
    --maxShapes=input1:42x160x160x6,input2:42x160x160x6

# Score model
/usr/src/tensorrt/bin/trtexec \
    --onnx="${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose/score_model.onnx" \
    --saveEngine="${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose/score_trt_engine.plan" \
    --minShapes=input1:1x160x160x6,input2:1x160x160x6 \
    --optShapes=input1:1x160x160x6,input2:1x160x160x6 \
    --maxShapes=input1:252x160x160x6,input2:252x160x160x6

echo "FoundationPose setup complete."
echo "You can now open a new terminal, run:  isaac-ros"
echo "and then use ros2 launch commands with \$ISAAC_ROS_WS."
