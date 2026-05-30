#!/bin/sh
echo "Starting module called module-01" >> /tmp/progress.log

systemctl restart code-server
