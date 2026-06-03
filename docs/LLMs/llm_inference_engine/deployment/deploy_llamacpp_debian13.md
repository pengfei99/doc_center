# Deploy llama.cpp on debian 13 server

In this tutorial, we will deploy a llama.cpp on a debian 13 server.


## 1. Install Build Dependencies

We recommend you to build `llama.cpp` from source, because based on your hardware configure, we need to build with different
`GGML hardware backend`.

So we need to install the required build tools first. Debian 13 includes `GCC 14`, which offers modern vectorization optimizations out of the box.

```shell
sudo apt update
sudo apt install -y build-essential cmake git curl libcurl4-openssl-dev pkg-config ccache
```

## 2. Get the source

Clone the `llama.cpp repository` into an appropriate directory, such as `/opt`.

```shell
sudo git clone https://github.com/ggerganov/llama.cpp /opt/llama.cpp
sudo chown -R $USER:$USER /opt/llama.cpp
cd /opt/llama.cpp
```

## 3. Choose your GGML backend

The `GGML backend is essential for hardware vector acceleration`. So you need to choose the right one based on your hardware

### 3.1 For Pure CPU Infrastructure (AVX2/AVX512)

If your Debian server runs on `standard x86_64` CPU hardware without dedicated GPUs, compile using `CPU vector acceleration`:

```shell
mkdir build && cd build

# check system and prepare the build file
cmake .. -DGGML_CPU=ON -DCMAKE_BUILD_TYPE=Release

# start the build process
cmake --build . --config Release --parallel $(nproc)
```

> In the output, you should see a line `Adding CPU backend variant ggml-cpu: -march=native`. It means
> llama.cpp delegates the hardware detection entirely to the GNU 14.2.0 compiler wrapper. Because the build system 
> automatically detected your `x86_64 architecture`, it injected the -march=native flag. 
> 
> This flag tells GCC 14: "Look at the CPU this server is currently running on, look at its exact hardware 
> capabilities (AVX2, AVX512, FMA), and compile the code using all of them."
> 
### 3.2 For NVIDIA GPU Acceleration (CUDA)

Debian 13 provides the `nvidia-cuda-toolkit` in its `non-free` component. Ensure contrib `non-free`, `non-free-firmware` 
are added to your `/etc/apt/sources.list`.

```shell
# install nvidia toolchain
sudo apt install -y nvidia-cuda-toolkit nvidia-driver

# build with cuda backend
mkdir build && cd build
cmake .. -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release --parallel $(nproc)
```

## 4. Model Provisioning

`llama.cpp` handles models in the GGUF format. We will create a structured storage hierarchy and download a 
balanced model, such as `Llama-3-8B-Instruct` quantified to 4-bits.

```shell
# Setup standard runtime directories
sudo mkdir -p /var/lib/llama-models
sudo chown -R $USER:$USER /var/lib/llama-models

# Download the model directly from HuggingFace
curl -L -o /var/lib/llama-models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf \
"https://huggingface.co/lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF/resolve/main/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf"
```

## 5. Test llama.cpp with llama-client

We have installed llama.cpp, downloaded a model. Now we can do some tests with ``llama-client`.
Check version first, because the commands change a lot based on your version

```shell
/opt/llama.cpp/build/bin/llama-cli --version
 
# expected output
version: 9377 (48e7eae41)
built with GNU 14.2.0 for Linux x86_64
```

> The below llama-client prompt command are tested with this version, if you use older or newer version, the below
> command may not work.

If you want to use the binaries without specify the path, you can add the binaries path into your `PATH`.

For a single user:
```shell
# add the binaries to your .bashrc
echo 'export PATH="/opt/llama.cpp/build/bin:$PATH"' >> ~/.bashrc

# reload your .bashrc
source ~/.bashrc
```

For all users:

```shell
# Create a new profile script
echo 'export PATH="/opt/llama.cpp/build/bin:$PATH"' | sudo tee /etc/profile.d/llama.sh

# make it executable
sudo chmod +x /etc/profile.d/llama.sh
```

### 5.1 One-and-Done Inline Prompt

```shell
/opt/llama.cpp/build/bin/llama-cli \
  -m /var/lib/llama-models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf \
  -p "System: You are an expert Debian SysAdmin.\nUser: Write a short bash script to check disk alerts.\nAssistant:" \
  -n 256 \
  -t 4
```

Parameter Breakdown:
- `-m`: specifies the model location
- `-p`: The explicit structural prompt. It specifies manual separation tags (System:, User:, Assistant:) so the model knows precisely where its text output generation needs to begin.

- `-n 256`: Caps generation at a maximum of 256 tokens to prevent the model from infinitely writing code or looping.

- `-t 4`: Sets execution parallelism constraints to 4 system threads (tune this matching your exact physical CPU core layout).


### 5.2 Interactive Chat Mode 

Modern `GGUF models` embed their exact text parsing structure directly into their file metadata 
(e.g., Llama 3 uses <|im_start|>, while Gemma uses <|start_of_turn|>). Instead of manually typing these system tags, 
you can tell `llama-cli` to look up and apply the model's native template automatically:

```shell
/opt/llama.cpp/build/bin/llama-cli \
  -m /var/lib/llama-models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf \
  -cnv \
  -p "You are an automated backup validation assistant."
```

Parameter Breakdown:
- `-cnv`: Activates the `Conversation/Chat Template mode`. It triggers an internal Jinja template parser that 
           automatically detects the structural format needed by the specific GGUF model you loaded.

- `-p`: Acts as your global System Prompt inside conversation mode, setting the model's behavior and constraints.


### 5.3 Deterministic JSON Schema Enforcement (Grammar Constraints)

When your infrastructure expects structured configuration file output, you can enforce hard programmatic rules using a 
`GBNF (GGML Backus-Naur Form) grammar template`. This forces the model's token selection process to only return 
syntactically valid outputs.

For instance, to ensure the model outputs nothing but a clean, structured JSON tracking array containing integers 
and strings:

```shell
/opt/llama.cpp/build/bin/llama-cli \
  -m /var/lib/llama-models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf \
  --grammar '
    root   ::= "{" ws "\"service\":" ws string "," ws "\"port\":" ws number "}" ws
    ws     ::= [ \t\n\r]*
    number ::= [0-9]+
    string ::= "\"" [a-zA-Z0-9_]* "\""
  ' \
  -p "User: Output the default SSH configuration schema as JSON."
```

> The model does not have notions about custom rules like `ws (whitespace), string, or number` inside your root entry.
> As a result we need to define them with explicite regex definitions.

In modern versioin, you can use `--json-schema` to specify the json structure directly

```shell
/opt/llama.cpp/build/bin/llama-cli \
  -m /var/lib/llama-models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf \
  --json-schema '{"type": "object", "properties": {"service": {"type": "string"}, "port": {"type": "integer"}}, "required": ["service", "port"]}' \
  -p "Output the default SSH configuration schema."

```

or you can create a schema file, and join the template file in the prompt with the command `-jf`.

```shell
# create a schema file
cat << 'EOF' > /tmp/my_schema.json
{
  "type": "object",
  "properties": {
    "service": { "type": "string" },
    "port": { "type": "integer" }
  },
  "required": ["service", "port"]
}
EOF

/opt/llama.cpp/build/bin/llama-cli \
  -m /var/lib/llama-models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf \
  -jf /tmp/my_schema.json \
  -p "Output the default SSH configuration schema." 
```

### 5.4 Use system command in a query

Suppose you have a log file at `/tmp/syslog`, and you want the llm to analyze the content of the file. The normal way is 
to copy the content of the file in the prompt. 

```shell
/opt/llama.cpp/build/bin/llama-cli \
  -m /var/lib/llama-models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf \
  -p "$(echo "Analyze this log file for kernel panic warnings:"; cat /tmp/syslog)" \
  -n 256 \
  -t 4
```

Or we can use `tail -n` to replace `cat`

```shell
/opt/llama.cpp/build/bin/llama-cli \
  -m /var/lib/llama-models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf \
  -p "$(echo "Analyze this log file for kernel panic warnings:"; tail -n 10 /tmp/syslog)" \
  -n 256 \
  -t 4
```


## 6. Run llama-server as daemon

Create a systemd config file `/etc/systemd/system/llama.service`

```shell
[Unit]
Description=Llama.cpp OpenAI-Compatible API Server
After=network.target

[Service]
Type=simple
User=llama
Group=llama
WorkingDirectory=/opt/llama.cpp
# --host 127.0.0.1 forces internal traffic bindings for security; Nginx will expose it safely
ExecStart=/opt/llama.cpp/build/bin/llama-server \
    -m /var/lib/llama-models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf \
    --host 127.0.0.1 \
    --port 8080 \
    -c 2048 \
    --n-gpu-layers 99
Restart=on-failure
RestartSec=5

# Linux Kernel sandbox security tuning
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/llama-models
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

> If running `CPU-only, remove --n-gpu-layers 99 or set it to 0`. 
> 
> If using a GPU, 99 tells the framework to offload all layers to VRAM.
> 
> 
To activate the daemon after reboot 

```shell
# reload daemon of systemd
sudo systemctl daemon-reload

# start, stop or check status of the daemon 
sudo systemctl start/stop/status llama.service

# enable daemon at reboot
sudo systemctl enable --now llama.service

# to check daemon journal/log
sudo journalctl -u llama.service -n 50 --no-pager
```

## 7. Setup reverse Proxy with Nginx 

Since the upstream daemon binds locally to `127.0.0.1:8080`, we will use Nginx to manage external traffic, provide 
safe network mapping, and prepare for TLS encryption certificates.

```shell
# install nginx
sudo apt install -y nginx
```

create a nginx profile configuration file for llama.cpp at `/etc/nginx/sites-available/llama`.

```shell
server {
    listen 80;
    server_name ai.casd.local; # Swap with your domain or server IP

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Disable buffering to handle real-time chunked token streaming cleanly
        proxy_buffering off;
        proxy_read_timeout 300s;
    }
}
```
Activate the profile and cycle the Nginx daemon:

```shell
sudo ln -s /etc/nginx/sites-available/llama /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

To check the end point, you can use the below curl commands

```shell
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "system", "content": "You are a helpful Debian sysadmin."},
      {"role": "user", "content": "Write a bash script to check memory usage."}
    ]
  }'
```
