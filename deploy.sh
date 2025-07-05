#!/bin/bash
# my own script to plug the binary into the minecraft server container. probably not going to work for you unless you COINCIDENTALLY has the EXACT SAME service setup as I do, in which case we should make love. /j
# 1. zip the code into zip
# 2. scp the zipped code into vm
# 3. delete any existing code in vm
# 4. unzip into codes dir
# 5. cargo build --release
# 6. scp compiled binary into pi's mc server dir
# 7. ssh pi to doas mv it from server to server/data
# 8. podman stop & restart

set -euo pipefail

source .env

ACTION="${1:-}"
if [[ "$ACTION" == "--launch-only" ]]; then
  echo "Stopping mc-logs-api in the container on Pi..."
  ssh $PI_USER@$PI_ADDR "podman exec -d $PI_MC_SERVER_CONTAINER_NAME pkill $APP_NAME"
  echo "Starting mc-logs-api in the container on Pi..."
  ssh $PI_USER@$PI_ADDR "podman exec -d $PI_MC_SERVER_CONTAINER_NAME /data/$APP_NAME"
    
  exit 0
fi

# 1. zip the code, excluding "target" folder
echo "Zipping code..."
cd "$CUR_DIR"
zip -r -x "target/*" -o "$ZIP_PATH" ./*

# 2. scp the zipped code into vm
echo "Copying zip to VM..."
scp "$ZIP_PATH" $VM_USER@$VM_ADDR:"$VM_CODES_DIR"

# 3. delete any existing code in vm
echo "Cleaning old code in VM..."
ssh $VM_USER@$VM_ADDR "rm -rf '$VM_UNZIP_DIR'"

# 4. unzip into "/home/windy/Codes"
echo "Unzipping code on VM..."
ssh $VM_USER@$VM_ADDR "unzip -o '$VM_CODES_DIR/$APP_NAME.zip' -d '$VM_UNZIP_DIR'"

# 5. cargo build --release
echo "Building on VM..."
ssh $VM_USER@$VM_ADDR "cd '$VM_UNZIP_DIR' && $VM_CARGO_PATH build --release"

# 6. scp compiled binary into pi @ /home/windy/Pods/minecraft-server
echo "Copying compiled binary to Pi..."
scp $VM_USER@$VM_ADDR:"$VM_UNZIP_DIR/target/release/$APP_NAME" $PI_USER@$PI_ADDR:"$PI_MC_SERVER_DIR/"

# 7. ssh pi to doas mv it from minecraft-server into minecraft-server/data
echo "Moving binary into container data dir on Pi..."
ssh -t $PI_USER@$PI_ADDR "doas mv '$PI_MC_SERVER_DIR/$APP_NAME' '$PI_MC_SERVER_DATA_DIR/'"

# 8. ssh pi podman exec -d generic-minecraft-server sh -c "pkill mc-logs-api && /data/mc-logs-api"
echo "Stopping mc-logs-api in the container on Pi..."
ssh $PI_USER@$PI_ADDR "podman exec -d $PI_MC_SERVER_CONTAINER_NAME pkill $APP_NAME"
echo "Starting mc-logs-api in the container on Pi..."
ssh $PI_USER@$PI_ADDR "podman exec -d $PI_MC_SERVER_CONTAINER_NAME /data/$APP_NAME"

echo "Done!"