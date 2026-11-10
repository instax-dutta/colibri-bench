# qwen-image-2.1 image benchmark 2026-11-09T18:23:22+00:00
coli commit: 0a5504a
model_dir: /home/tejes/colibri-models/qwen-image-2.1 size 33.1GB
method: coli start + timed POST /v1/images/generations (768x512)
--- start ---
  updating: make qwenimage ARCH=native  (only what changed since the last build; log: /home/tejes/.local/share/colibri/logs/build-cpu.log)
  up to date
  Browser:             http://127.0.0.1:8000/
  OpenAI base URL:     http://127.0.0.1:8000/v1
  Anthropic base URL:  http://127.0.0.1:8000
  stop: press Ctrl+C here (or close this window)

dashboard: http://127.0.0.1:8000/  (opens automatically when the engine is ready)
[qwenimage] text encoder: 36 layers, 6.95 GB resident (int8), 23.5 s
[qwenimage] transformer: 32 blocks, 7.09 GB resident, 25.4 s
[image] qwen-image-2.1-colibri: default 768x512, 8 steps
OpenAI-compatible API listening on http://127.0.0.1:8000/v1
[api] 127.0.0.1 - "GET /v1/models HTTP/1.1" 200 -
--- result ---
http=200 time=862.547713s (14m22s) size=573967B (PNG b64, 768x512, steps=8 default)
model=qwen-image-2.1-colibri prompt="a red cube on a table"
method: coli start --background, ready, POST /v1/images/generations
server: qwenimage --serve (pid 1966577), CPU 732% avg, RSS ~13GB at load
note: first attempt hung 41min foreground coli start (no request sent); fixed to background + model field; this run is the valid measurement
