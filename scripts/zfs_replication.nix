_: ''
  SOURCE_DATASET="nvme_pool"
  TARGET_DATASET="hdd_pool/replication"
  TARGET="$TARGET_DATASET/$SOURCE_DATASET"
  SSH_USER="root"
  DEST_HOST="192.168.0.15"

  LATEST_SNAP=$(
    zfs list -t snapshot -H -o name -s creation -d1 "$SOURCE_DATASET" | tail -1 | cut -d'@' -f2
  )
  echo "latest snapshot: $LATEST_SNAP"

  # Get latest snapshot on destination (if exists)
  DEST_LATEST_SNAP=$(
    sudo ssh "$SSH_USER@$DEST_HOST" "zfs list -t snapshot -H -o name -s creation -d1 $TARGET | tail -1 | cut -d'@' -f2"
  )
  echo "DEST_LATEST_SNAP $DEST_LATEST_SNAP"

  SOURCE="$SOURCE_DATASET@$LATEST_SNAP"
  if [ -z "$DEST_LATEST_SNAP" ]; then
    # Full send
    echo "Performing full replication from $SOURCE to $TARGET"
    sudo zfs send -R $SOURCE | sudo ssh "$SSH_USER@$DEST_HOST" sudo zfs receive -F $TARGET
  else
    echo "Doing incremental send..."
    # Check if DEST_LATEST_SNAP exists locally, otherwise pick the first available local snapshot
    LOCAL_DEST_LATEST_SNAP=$(zfs list -t snapshot -H -o name -s creation -d1 "$SOURCE_DATASET" | rg $DEST_LATEST_SNAP | cut -d'@' -f2)
    echo "LOCAL_DEST_LATEST_SNAP $LOCAL_DEST_LATEST_SNAP"
    if [ -z "$LOCAL_DEST_LATEST_SNAP" ]; then
      echo "Destination snapshot no longer exists locally. Using older local snapshot instead"
      SOURCE_SNAP=$(zfs list -t snapshot -H -o name -d1 $SOURCE_DATASET | head -1 | cut -d'@' -f2)
    else
      SOURCE_SNAP=$DEST_LATEST_SNAP
    fi

    # Incremental send
    echo "Performing incremental replication from @$SOURCE_SNAP to @$LATEST_SNAP..."
    sudo zfs send -R -I "$SOURCE_DATASET@$SOURCE_SNAP" $SOURCE | sudo ssh "$SSH_USER@$DEST_HOST" zfs receive -F $TARGET
  fi
''
