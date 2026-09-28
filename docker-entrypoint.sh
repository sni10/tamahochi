#!/bin/sh
# Поднимаем виртуальный дисплей, VNC и noVNC, затем запускаем игру.
# Аргументы контейнера передаются в main.py (например: --speed 60).
set -e

Xvfb "$DISPLAY" -screen 0 "$SCREEN" -nolisten tcp &
sleep 1
x11vnc -display "$DISPLAY" -forever -shared -nopw -quiet -rfbport 5900 &
websockify --web /usr/share/novnc 6080 localhost:5900 >/dev/null 2>&1 &

echo "Tamahochi: http://localhost:6080/vnc.html?autoconnect=1&resize=scale"
exec python3 main.py "$@"
