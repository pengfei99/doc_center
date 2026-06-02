# Overview of llama.cpp

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

## 1 Application layer

When we compile `llama.cpp`, the build system produces several distinct application components:
- llama-server
- llama-client
- llama-quantize

These are located in the `examples/` or `tools/` directories. These components are standalone binaries.

These component allow users to interact with the LLM models deployed with llama.cpp.

### 1.1 Llama-server

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

### 1.2 llama-cli (The Local Client / Tool)

llama-cli ia a full-featured `command-line utility` used for:
- localized interaction, 
- testing
- benchmarking
- batch scripting.

It provides:
- `Interactive Chat Mode`: which turns your terminal into a persistent conversational assistant while retaining state memory.
- `precise, granular parameter injection`: which can adjust parameters like `temperature, top_p, top_k, or context window` constraints directly via terminal arguments.

### 1.3 llama-quantize (The Optimization Compactor)

`llama-quantize` allows consumer hardware to run massive models by shrinking weight precisions down from `standard 16-bit floats (FP16)`.

It supports :
- `modern K-quants` (e.g., Q4_K_M, Q5_K_S).
- `block-wise quantization`
- allocating higher precision bitrates to critical attention layers
- allocation lower bitrates to less sensitive feed-forward weights

It can drop model sizes by up to 75% while keeping perplexity loss remarkably low.

## 2 Model layer (libllama)

`libllama` is a C-Style API which is exposed via `include/llama.h`, this layer translates the low-level tensor 
operations into transformer-specific architectures.

- It handles `GGUF file ingestion` (parsing weights, tokenizers, and metadata seamlessly).
- It manages the `KV Cache (Key-Value Cache)`, which stores past token contexts so that the model doesn’t have to recompute the entire conversation history on every new token.
- It hosts the model-specific graph builders (e.g., Llama, Mistral, Gemma, Qwen architectures are mapped onto GGML operations here).

## 3 GGML layer

`GGML` is a pure C machine learning library written by `Georgi Gerganov`, which is the core of `llama.cpp`

> llama.cpp does not use `PyTorch, TensorFlow, or ONNX`. 

GGML has two tasks:
- manage `Computation Graphs`: GGML represents model evaluation as a `static computation graph`. Tensors (weights and activations) 
                         are defined as nodes, and operations (matrix multiplication, RoPE, Softmax) are edges.
- manage `execution memory allocation`: During initialization, llama.cpp calculates the exact memory required for the entire evaluation graph. 
                           `Memory is allocated once at startup (ggml_gallocr)`. During inference, memory is reused 
                          continuously, ensuring zero runtime heap allocations and avoiding garbage collection or memory fragmentation overhead.

## 4 GGML Hardware Backend

To maintain portability, GGML abstracts the underlying computing hardware via a unified `backend interface (ggml-backend)`. 
This allows llama.cpp to run across different hardware architectures:

- `ggml-cpu`: Tailored for system processors. Uses advanced SIMD instructions (AVX2, AVX-512 on Intel/AMD; NEON, SVE on ARM Graviton/Apple Silicon) to vectorize matrix multiplication.

- `ggml-cuda`: Offloads computation graphs to NVIDIA graphics cards. It splits layers across multiple GPUs if VRAM is insufficient.

- `Other Backends`: Includes Metal (Apple Silicon), Vulkan (AMD/Intel/Cross-platform), ROCm (AMD Enterprise), and RPC (for clustering multiple distributed servers over a network).
