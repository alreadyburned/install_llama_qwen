[Unit]
Description=Llama.cpp Server for Qwen 2.5 14B
After=network.target Sprv-node.service

[Service]
User=nysa21
WorkingDirectory=/home/nysa21/models
ExecStart=/home/nysa21/models/llama-server \
    -m /home/nysa21/models/qwen2.5-coder-14b-instruct-q4_k_m.gguf \
    -ngl 49 \
    -c 8192 \
    --port 8080 \
    --host 0.0.0.0

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target