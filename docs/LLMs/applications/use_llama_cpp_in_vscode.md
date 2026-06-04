# Use llama.cpp as VSCode code completion backend

## Choose model

For code completion (Tab-autocomplete), you cannot use a standard chat model. You need a model trained for FIM (Fill-in-the-Middle) tasks, and it needs to be small enough to react instantly.

- Top Pick: Qwen2.5-Coder-1.5B-Instruct or Qwen2.5-Coder-3B-Instruct (GGUF format).

- Alternative: DeepSeek-Coder-1.5B (GGUF format).

> Download a highly quantized version (like Q4_K_M or Q8_0) from Hugging Face to maximize speed.
> 
## Run the llama.cpp server

Run the following command in your terminal to start the server optimized for code autocomplete:

```powershell
.\llama-server.exe -m "C:\Users\pliu\Documents\tools\llama.cpp\models\qwen2.5-coder-3b-instruct-q4_k_m.gguf" -c 4096 --n-gpu-layers 0 --host 0.0.0.0 --port 8012 --cont-batching
```

Critical Flags Explained:
- `-ngl 99 (No. of GPU Layers)`: Pushes all layers to your GPU (CUDA/Metal) for lightning-fast token generation. Set to 0 if running purely on CPU.

- `-c 4096`: Restricts the context window to 4K tokens. You don't want the server parsing a 32K context window for a simple line completion, as it destroys latency.

- `--cont-batching`: Enables continuous batching, which is vital if you have multiple files or tabs hitting the server simultaneously.

## Integrating into VS Code

There are two primary ways to do this: using the official llama-vscode extension (optimized natively for llama.cpp) or Continue (a highly customizable, industry-standard choice).

### Option A: The Native Way (llama-vscode)


The ggml-org team provides an official, lightweight extension built directly for this workflow.

Open VS Code, go to the Extensions Marketplace, and install llama-vscode (by ggml.ai).

Open your VS Code global settings (Ctrl + , or Cmd + ,), search for llama-vscode, or edit your settings.json directly:

```json
{
  "llama-vscode.endpoint": "http://127.0.0.1:8012",
  "llama-vscode.autocomplete.enable": true,
  "llama-vscode.autocomplete.maxTokens": 64
}
```


### Option B: The Advanced Way (Continue Extension)
If you want both a sidebar chat and Tab-autocomplete with deep customization, use Continue.

Install the Continue extension from the VS Code Marketplace.

Click the gear icon on the Continue sidebar to open its configuration file (config.json or config.yaml).

Add or modify the models and tabAutocompleteModel sections:

```json
{
  "models": [
    {
      "title": "Llama.cpp Code Chat",
      "provider": "llama.cpp",
      "model": "qwen2.5-coder",
      "apiBase": "http://127.0.0.1:8012/v1"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Llama.cpp FIM",
    "provider": "llama.cpp",
    "model": "qwen2.5-coder",
    "apiBase": "http://127.0.0.1:8012/v1"
  },
  "tabAutocompleteOptions": {
    "debounceDelay": 150,
    "maxPromptTokens": 1024
  }
}
```

> Tip: Setting "debounceDelay": 150 means the model waits 150ms after you stop typing before firing a request, saving your system from processing incomplete thoughts.