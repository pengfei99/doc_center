# Deploy llama cpp on windows

## 1. Build from source

### Step 1: Install Prerequisites

1. Install `Visual Studio 2022 Community (recommended)`
2. Download from: https://visualstudio.microsoft.com/downloads/
3. Select Desktop development with C++ workload
4. Also select: C++ CMake tools for Windows

For `CUDA Toolkit (if you have NVIDIA GPU)`
1. Download latest compatible version (CUDA 12.4 or 13.x) from NVIDIA Developer site.
2. Match it with your GPU architecture (e.g., RTX 40/50 series works great with CUDA 12.6+ / 13).

> Git (comes with Visual Studio or install separately)

### Step 2: Build llama.cpp

Open Developer Command Prompt for VS 2022 (important!) and run:

```powershell
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Create build directory
mkdir build && cd build

# Configure with CUDA (best performance)
cmake .. -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release

# Build (use -j for faster build)
cmake --build . --config Release -j 8
```

For newer GPUs (e.g. RTX 50-series / Blackwell), add: `-DCMAKE_CUDA_ARCHITECTURES=120`
## 2. Pre-built binaries

The [github repo](https://github.com/ggerganov/llama.cpp/releases) of llama.cpp provides the pre-built binaries

Based on your hardware, you can download the appropriate built. For example if you have GPU, you can download the latest `llama-*-bin-win-cuda-xx-x64.zip`
If you only have cpu, you can download the lates `llama-*-bin-win-cpu-x64.zip` (https://github.com/ggml-org/llama.cpp/releases/download/b9505/)

Extract the zip and you will find `llama-server.exe`.

## 4: Deploy llama-server (Production Mode)

After successful build, go to: `llama.cpp\build\bin\Release\`, you will find `llama-server.exe`
The best way to "deploy" it is to launch a llama-cpp in server mode:

```powershell
# simple server
.\llama-server.exe -m "C:\Users\pliu\Documents\tools\llama.cpp\models\Meta-Llama-3-8B-Instruct-Q4_K_M.gguf" -c 32768 --n-gpu-layers 0 --host 0.0.0.0 --port 8080

# with native tools enabled
.\llama-server.exe -m "C:\Users\pliu\Documents\tools\llama.cpp\models\Meta-Llama-3-8B-Instruct-Q4_K_M.gguf" -c 32768 --n-gpu-layers 0 --host 0.0.0.0 --port 8080 --tools all
```

Useful flags for deployment:

- `--host 0.0.0.0`: accessible from network
- `--port 8080`: 
- `-ngl 99` or `--n-gpu-layers 99` : offload as many layers as possible to GPU
- `--ctx-size 32768` (or higher)
- `--flash-attn` (enable Flash Attention for speed)
- `--api-key` your-secret-key (for security)
- `--tools all`: enable all default tools, if you want to enable specific tools, you can add tool-name after tools