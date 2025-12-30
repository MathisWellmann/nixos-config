{pkgs, ...}:
pkgs.writeShellScriptBin "zfs_replication" ''
  SOURCE_DATASET="nvme_pool"
  TARGET_DATASET="hdd_pool/replication"
  SSH_USER="root"
  DEST_HOST="192.168.0.15"

  LATEST_SNAP=$(zfs list -t snapshot -H -o name -d1 "$SOURCE_DATASET" | tail -1 | cut -d'@' -f2)
  echo "latest snapshot: $LATEST_SNAP"
  
  # Get latest snapshot on destination (if exists)
  DEST_LATEST_SNAP=$(sudo ssh "$SSH_USER@$DEST_HOST" "sudo zfs list -t snapshot -H -o name -s creation -d1 $DEST_DATASET 2>/dev/null | tail -1 | cut -d'@' -f2")
  echo "DEST_LATEST_SNAP=$DEST_LATEST_SNAP"

  SOURCE="$SOURCE_DATASET@$LATEST_SNAP"
  TARGET="$TARGET_DATASET/$SOURCE_DATASET"
  if [ -z "$DEST_LATEST_SNAP" ]; then
    # Full send
    echo "Performing full replication from $SOURCE to $TARGET"
    sudo zfs send -R $SOURCE | sudo ssh "$SSH_USER@$DEST_HOST" sudo zfs receive -F $TARGET
  else
    # Incremental send
    echo "Performing incremental replication from @$DEST_LATEST_SNAP to @$LATEST_SNAP..."
    sudo zfs send -R -I "@$DEST_LATEST_SNAP" $SOURCE | sudo ssh "$SSH_USER@$DEST_HOST" sudo zfs receive -F $TARGET
  fi
''
