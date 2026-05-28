# Deploy llama.cpp on debian 13 server

In this tutorial, we will deploy a llama.cpp on a debian 13 server.

## 1. overview of llama.cpp

The below figure shows the workflow of how a network request flows through the main components of the llama.cpp

```text
[ Web UI / External App ]
         │ (HTTP JSON Request / OpenAI API)
         ▼
 ┌────────────────────────────────────────────────────────┐
 │         llama-server(application layer)                │
 │  - server_http_context (Accepts Network Connection)    │
 │  - server_queue        (Thread-safe Job Handling)      │
 │  - server_slot         (Parallel Inference Management) │
 └───────┬────────────────────────────────────────────────┘
         │ (Context Extraction & Tokenization)
         ▼
 ┌────────────────────────────────────────────────────────┐
 │              libllama (model layer)                    │
 │  - KV Cache Management & Prompt Prefix Matching        │
 │  - Transformer Graph Construction (Llama/Gemma/etc.)   │
 └───────┬────────────────────────────────────────────────┘
         │ (Static Graph Nodes)
         ▼
 ┌────────────────────────────────────────────────────────┐
 │                     GGML                               │
 │  - Graph Allocator (`ggml_gallocr`)                    │
 │  - Matrix Operations Engine                            │
 └───────┬────────────────────────────────────────────────┘
         │ (Unified Hardware Drivers)
         ▼
 ┌────────────────────────────────────────────────────────┐
 │               ggml-backend Ecosystem                   │
 │  [ggml-cuda]        [ggml-cpu]         [ggml-vulkan]   │
 └────────────────────────────────────────────────────────┘
```

### 1.1 Application layer

When we compile `llama.cpp`, the build system produces several distinct application components:
- llama-server
- llama-client
- llama-quantize

These are located in the `examples/` or `tools/` directories. These components are standalone binaries.

These component allow users to interact with the LLM models deployed with llama.cpp.

#### Llama-server

The `Llama-server` launches an enterprise-grade HTTP server component. It maps the local C++ model pipeline to an http endpoint.
This endpoint provides:
- `OpenAI-Compatible Engine`: It mirrors OpenAI’s `/v1/chat/completions`, `/v1/embeddings`, and `/v1/completions` API 
                            schema natively, allowing you to drop it into existing enterprise frameworks (e.g. `LangChain, AutoGen, or LlamaIndex`) 
                           without modifying code.

- `Parallel Slot Management (server_slot)`: The server introduces the concept of slots. If configured with multiple slots, 
                       it processes multiple concurrent user requests in parallel, intelligently packing sequences 
                          into a single matrix batch to maximize hardware utilization.

- `Continuous Batching & Prompt Checkpointing`: It dynamically adds new requests into the current execution loop without 
                    stopping active token generations. It also saves snapshots of the prefix KV cache (server_prompt_checkpoint) 
                    so that if multiple users share the same system prompt, the server skips re-evaluating it.

- `Native SvelteKit Web UI`: Modern versions of llama-server include an `embedded web UI` that streams token generation 
                     and provides a clean interface for debugging prompts and testing configurations.

#### llama-cli (The Local Client / Tool)

llama-cli ia a full-featured `command-line utility` used for:
- localized interaction, 
- testing
- benchmarking
- batch scripting.

It provides:
- `Interactive Chat Mode`: which turns your terminal into a persistent conversational assistant while retaining state memory.
- `precise, granular parameter injection`: which can adjust parameters like `temperature, top_p, top_k, or context window` constraints directly via terminal arguments.

#### llama-quantize (The Optimization Compactor)

`llama-quantize` allows consumer hardware to run massive models by shrinking weight precisions down from `standard 16-bit floats (FP16)`.

It supports :
- `modern K-quants` (e.g., Q4_K_M, Q5_K_S).
- `block-wise quantization`
- allocating higher precision bitrates to critical attention layers
- allocation lower bitrates to less sensitive feed-forward weights

It can drop model sizes by up to 75% while keeping perplexity loss remarkably low.

### 1.2 Model layer (libllama)

`libllama` is a C-Style API which is exposed via `include/llama.h`, this layer translates the low-level tensor 
operations into transformer-specific architectures.

- It handles `GGUF file ingestion` (parsing weights, tokenizers, and metadata seamlessly).
- It manages the `KV Cache (Key-Value Cache)`, which stores past token contexts so that the model doesn’t have to recompute the entire conversation history on every new token.
- It hosts the model-specific graph builders (e.g., Llama, Mistral, Gemma, Qwen architectures are mapped onto GGML operations here).

### 1.3 GGML layer

`GGML` is a pure C machine learning library written by `Georgi Gerganov`, which is the core of `llama.cpp`

> llama.cpp does not use `PyTorch, TensorFlow, or ONNX`. 

GGML has two tasks:
- manage `Computation Graphs`: GGML represents model evaluation as a `static computation graph`. Tensors (weights and activations) 
                         are defined as nodes, and operations (matrix multiplication, RoPE, Softmax) are edges.
- manage `execution memory allocation`: During initialization, llama.cpp calculates the exact memory required for the entire evaluation graph. 
                           `Memory is allocated once at startup (ggml_gallocr)`. During inference, memory is reused 
                          continuously, ensuring zero runtime heap allocations and avoiding garbage collection or memory fragmentation overhead.

### 1.4 GGML Hardware Backend

To maintain portability, GGML abstracts the underlying computing hardware via a unified `backend interface (ggml-backend)`. 
This allows llama.cpp to run across different hardware architectures:

- `ggml-cpu`: Tailored for system processors. Uses advanced SIMD instructions (AVX2, AVX-512 on Intel/AMD; NEON, SVE on ARM Graviton/Apple Silicon) to vectorize matrix multiplication.

- `ggml-cuda`: Offloads computation graphs to NVIDIA graphics cards. It splits layers across multiple GPUs if VRAM is insufficient.

- `Other Backends`: Includes Metal (Apple Silicon), Vulkan (AMD/Intel/Cross-platform), ROCm (AMD Enterprise), and RPC (for clustering multiple distributed servers over a network).

## 2. Install Build Dependencies

We recommend you to build `llama.cpp` from source, because based on your hardware configure, we need to build with different
`GGML hardware backend`.

So we need to install the required build tools first. Debian 13 includes `GCC 14`, which offers modern vectorization optimizations out of the box.

```shell
sudo apt update
sudo apt install -y build-essential cmake git curl libcurl4-openssl-dev pkg-config ccache
```

## 3. Get the source

Clone the `llama.cpp repository` into an appropriate directory, such as `/opt`.

```shell
sudo git clone https://github.com/ggerganov/llama.cpp /opt/llama.cpp
sudo chown -R $USER:$USER /opt/llama.cpp
cd /opt/llama.cpp
```

## 4. Choose your GGML backend

The `GGML backend is essential for hardware vector acceleration`. So you need to choose the right one based on your hardware

### 4.1 For Pure CPU Infrastructure (AVX2/AVX512)

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
### 4.2 For NVIDIA GPU Acceleration (CUDA)

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

## 5. Model Provisioning

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

## 6. Test llama.cpp with llama-client

## 7. Run llama-server as daemon

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

```

## 8. Setup reverse Proxy with Nginx 

Since the upstream daemon binds locally to `127.0.0.1:8080`, we will use Nginx to manage external traffic, provide 
safe network mapping, and prepare for TLS encryption certificates.

```shell
# install nginx
sudo apt install -y nginx
```

create a configuration file for llama.cpp at `/etc/nginx/sites-available/llama`.

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

