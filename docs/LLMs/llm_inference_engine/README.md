# LLM Inference Engine

A `LLM inference engine` is the software responsible for executing a `trained LLM model` and generating outputs
from inputs.

During the training of the LLM models, the weights in the neuron network are adjusted. The job of inference engine:

1. Load model weights
2. Tokenize input
3. Execute transformer computations
4. Generate tokens
5. Covert tokens to text, then return text

Examples of popular inference engines:

- llama.cpp
- vLLM
- TensorRT-LLM
- SGLang

> Hugging face `Text Generation Inference (TGI)` is no longer supported, so we exclude it from the list



## 1. How Inference Engine works

Here we only briefly introduce the General architecture and Internal Components of a Modern Inference Engine.

If you want more details, you can check this doc [How_inference_engine_works.md](./How_inference_engine_works.md)

## 2. How to measure the performence of an Inference Engine?

A high-quality inference engine optimizes:

- Compute
    - Fast matrix multiplication
    - GPU utilization
- Memory
    - Efficient KV cache
    - Quantization
- Scheduling
    - Batch multiple users
- Latency
    - Fast first token
- Throughput
    - High tokens/sec
      Compatibility
    - Many model architectures
  
## 2. How to choose an Inference Engine?

There is no universal `best inference engine`. It highly depends on:
- hardware: CPU vs GPU, memory capacity, etc.
- ease of deployment: easy vs hard
- single-user latency: Time for the first token
- concurrent throughput: 
- multi model archi/format support:
- structured agent workflow execution:

## 3. Quick preview of popular inference engines.

### 3.1 Llama.cpp

`Llama.cpp` is best for:
- Local experimentation
- prototyping
- running specialized quantizations (GGUF, IQ4, Q4_K_M) on a wide range of hardware.

Strengths:

- Memory Efficiency: Features low overhead for running models across CPU/GPU setups.
- Format Support: First-class support for GGUF quants, allowing fine control over memory allocation.
- Zero Setup Hassle: Standalone executable (llama-cli / llama-server) with integrated OpenAI-compatible endpoint.

Weaknesses:

- Lacks advanced continuous batching architectures and optimized kernel backends built for multi-user high-throughput serving.

> Excellent for single-user dev environments, quick testing, or running custom GGUFs.

You can check this [doc](./llama_cpp.md) to know more about llama.cpp(e.g architecture)

This [doc](./deployment/deploy_llamacpp_debian13.md) shows how to deploy llama.cpp on debian server.

### 3.2 vllm

You can check this [doc](./vllm.md) to know more about vllm(e.g. architecture).

This [doc](./deployment/deploy_vllm_debian13.md) shows how to deploy vllm on debian server.

## vllm vs llama.cpp

**vLLM and llama.cpp are designed for different goals.**

A quick summary

| Feature               | llama.cpp                              | vLLM                                 |
|-----------------------|----------------------------------------|--------------------------------------|
| Primary goal          | Run LLMs efficiently on local hardware | Serve LLMs efficiently to many users |
| CPU support           | Excellent                              | Poor                                 |
| GPU requirement       | Optional                               | Essentially required                 |
| Single-user laptop    | Excellent                              | Overkill                             |
| Multi-user API server | Limited                                | Excellent                            |
| GGUF support          | Native                                 | No                                   |
| HuggingFace models    | Limited                                | Native                               |
| Throughput            | Good                                   | Excellent                            |
| Memory optimization   | Quantization                           | PagedAttention                       |
| OpenAI-compatible API | Possible                               | Built-in                             |
| Production serving    | Good                                   | Excellent                            |

llama.cpp advantages:

- Simple binaries
- GGUF models
- CPU support
- Small footprint
- Easy offline deployment

vLLM advantages:

- Better serving at scale
  Better multi-user support
  Better GPU utilization



