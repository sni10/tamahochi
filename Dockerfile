# Tamahochi в контейнере: tkinter рисует в виртуальный дисплей Xvfb,
# картинка отдаётся в браузер через noVNC — http://localhost:6080
FROM debian:bookworm-slim

# python3 (3.11) + tkinter, виртуальный X-сервер, VNC-сервер и веб-клиент noVNC.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 python3-tk \
        xvfb x11vnc novnc websockify \
        fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Сторонних pip-пакетов сейчас нет; если появятся — впишите в requirements.txt,
# и раскомментируйте строки ниже (плюс python3-pip в apt-get выше).
COPY requirements.txt .
# RUN pip3 install --no-cache-dir --break-system-packages -r requirements.txt

COPY . .
# sed — на случай, если скрипт пришёл из Windows с CRLF
RUN sed -i 's/\r$//' docker-entrypoint.sh && chmod +x docker-entrypoint.sh

ENV DISPLAY=:99 \
    SCREEN=480x1000x24 \
    TAMAHOCHI_DATA=/data \
    PYTHONUNBUFFERED=1

VOLUME /data
EXPOSE 6080

ENTRYPOINT ["./docker-entrypoint.sh"]
