#!/bin/sh

PROJECT_DIR=/mnt/jffs2/Install_gram/hg8245h5-repeater
BACKUP_DIR=/mnt/jffs2/Install_gram/hg8245h5-repeater-backup

if [ -x "$BACKUP_DIR/control_audit.sh.original" ]; then
    "$BACKUP_DIR/control_audit.sh.original" "$@"
fi

case "$1" in
    --start)
        start-stop-daemon -S -b -x "$PROJECT_DIR/repeater_bootstrap.sh"
        ;;
    --stop_clean)
        if [ -s /var/run/hg5r-service.pid ]; then
            kill "$(cat /var/run/hg5r-service.pid)" 2>/dev/null || true
        fi
        ;;
esac

exit 0
