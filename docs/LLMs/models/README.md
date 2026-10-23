# LLMs


## Model file format

Think of a `Model File Format` as a physical shipping container. It doesn't care about the payload (e.g. tokenizer,
architecture, weights, etc.) inside.
Its job is to organize data so a `Inference Engine` can read it and run it safely and efficiently.

A LLM consists three types of data:

- The `Architecture/Metadata`: A blueprint detailing how many layers the model has, how many attention heads it uses,
  and what its configuration settings are.
- The `Tokenizer Data`: The vocabulary rules that convert words into embeddings.
- The `Weights (Tensors)`: Billions of matrix multiplication numbers that represent the model's actual "brain power."

Below is a list of popular model file formats:

| Format                    | Best match inference engine            | Main Use Case                                                  | Strengths                                                                                                      | Weaknesses                                | Status (2026)       |
|---------------------------|----------------------------------------|----------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|-------------------------------------------|---------------------|
| GGUF                      | llama.cpp, vLLM(with conditions)       | General LLM inference for CPU                                  | Best quantization, ecosystem support                                                                           | -                                         | Dominant standard   |
| Safetensors(Hugging Face) | vLLM, TensorRT-LLM                     | Training + inference                                           | Very safe, fast loading, popular                                                                               | Usually FP16/BF16 (large files)           | Extremely popular   |
| GGML bin file(.bin)       | whisper.cpp and llama.cpp(old version) | store OpenAI’s original PyTorch Whisper models for whisper.cpp | very efficiently on CPU                                                                                        | legacy format, only works for whisper.cpp | Declining           |
| PyTorch (.pth, .pt)       | Meta                                   | Research & training                                            | Most flexible during training                                                                                  | Not optimized for inference               | Still very common   |
| ONNX(Microsoft)           | ONNX Runtime                           | Cross-framework inference                                      | Great interoperability                                                                                         | More complex, heavier                     | Popular in industry |
| TensorRT(NVIDIA)          | TensorRT-LLM                           | Maximum GPU speed                                              | Blazing fast on NVIDIA GPUs                                                                                    | NVIDIA-only, hard to quantize             | Niche (high-end)    |
| OpenVINO(Intel)           | OpenVINO GenAI                         | optimized specifically for Intel hardware                      | It consists of two files: an .xml file describing the network topology and a .bin file containing the weights. | Intel’s proprietary model format          | not popular         |

We recommend you to use `GGUF`, because Many tools (Ollama, LM Studio, SillyTavern, Faraday.dev, etc.) now only support
`GGUF` or convert everything to it internally.

> If you have enterprise grid of GPUs, and you use `vLLM` as inference engine, you need to use `Safetensors`, because
> vLLM does not support GGUF natively, when you serve GGUF with vLLM, vLLM first convert GGUF to Safetensors, and the
> converter is very buggy.

## Quantization Algorithms and Quantization rules

A `quantization algorithm` is the analytical process used to determine which weights can be shrunk and how to shrink 
them `without destroying the model's intelligence`. 

If you blindly round all numbers in an LLM matrix to the nearest integer (naive quantization), the model will start 
outputting gibberish. This is because neural networks contain `salient weights`—a tiny fraction (around 1%) of 
parameters that carry a massive amount of the model's semantic knowledge

A good Quantization algorithm figures out which 1% of a model's weights are "salient" (critical for accuracy) based 
on real data activations and keeps those at higher precision, while crushing the remaining 99% down to 4-bit.

| Format Class                                   | Flag Identifier | Optimal Target Hardware Backend | Notes                                                                               |
|------------------------------------------------|-----------------|---------------------------------|-------------------------------------------------------------------------------------|
| AWQ(Activation-aware Weight Quantization)      | awq             | NVIDIA GPUs / Intel CPUs        | "High throughput, great multi-user scaling."                                        |
| GPTQ(layer-by-layer second-order optimization) | gptq            | NVIDIA GPUs / Intel CPUs        | Classic 4-bit standard.                                                             |
| Marlin                                         | marlin          | NVIDIA GPUs (Ampere+)           | A hyper-fast kernel wrapper for specialized 4-bit configurations.                   |
| FP8                                            | fp8             | "NVIDIA (Ada/Hopper/Blackwell)  | AMD (MI300+), Near-zero accuracy loss. Highly efficient for newer architectures.    |
| BitsAndBytes                                   | bitsandbytes    | NVIDIA GPUs                     | "Supports 4-bit (nf4/fp4) and 8-bit on the fly. Slower, but retains high accuracy." |
| GGUF                                           | gguf            | NVIDIA GPUs / AMD GPUs          | Experimental. Requires external tokenizers.                                         |
| TorchAO                                        | torchao         | CPU / GPU                       | Uses PyTorch's native architecture optimization formats (INT8/INT4 dynamic).        |

### Quantization rules

Once the `quantization algorithm` decides which weights can be shrunk, the `Quantization Rules` dictate how those `weights are mathematically grouped, scaled, and physically arranged`
so hardware (CPU or GPU) can compute them. Because an `integer (INT4) cannot natively represent a decimal point`, 
quantization rules use specific mathematical structures to map integers back into floating-point spaces during active matrix multiplication.

The Core Quantization Rules/Concepts:
- `Block/Group Size Rules`: `weights are chopped into blocks` or groups (typically sizes of 32, 64, or 128). For example, 
                a group size of 64 means that every sequence of 64 weights shares a single, highly precise floating-point "scale factor." 
                Lower group sizes mean better model accuracy but a slightly larger file size.
- `Symmetric vs. Asymmetric Mapping`: This dictates how the number range is mapped.
                  - Symmetric: The rule clamps the mathematical range perfectly around zero (e.g., mapping float ranges from $-X$ to $+X$ directly to integer ranges $-127$ to $+127$). 
                                 It is computationally fast because you only need a scale factor.
                  - Asymmetric: The rule maps arbitrary ranges (e.g., $-0.2$ to $+0.8$). This requires both a Scale Factor and a Zero-Point offset, making the math slightly heavier but more accurate for skewed weight data.
- `Grid Formatting`: In formats like `GGUF`, the quantization rules are strictly standardized into predefined types called "K-Quants" (Q4_K_M, Q5_K_S, etc.).
                     For example, the rule for `Q4_K_M` states: Structure the weights into blocks of 256. Quantize the lower layers using 4-bit structures, but use a 6-bit structure for the critical attention matrices.

### GGUF VS AWQ

Here, we refer `GGUF` as quantization algorithm not model file format

## What is GGUF?

`GGUF (GGML Unified Format)` is a binary file format designed specifically for storing and running Large Language
Models efficiently, especially on CPU and consumer hardware.

> GGUF is also a `Quantization Format`, in GGUF file, the model weights are internally compressed using their
`proprietary GGML quantization math (like Q4_K_M)`.

It was developed as part of the llama.cpp project (by Georgi Gerganov) as the successor to the older GGML format.
Key Features of GGUF:

- `Single-file format`: Contains everything — model weights, architecture config, tokenizer, metadata, etc.
- `Quantization-first design`: Excellent support for various quantization methods (Q2_K, Q3_K, Q4_0, Q4_K, Q5_K, Q6_K,
  Q8_0, FP16, BF16, etc.).
- `Highly efficient`: Optimized for fast loading and inference, especially with llama.cpp, Ollama, LM Studio, GPT4All,
  etc.
- `Hardware flexibility`: Works great on CPU, GPU (via Vulkan, CUDA, Metal, etc.), and even mobile/edge devices.
- `Extensible`: Supports custom metadata, versioning, and future-proofing.
- `Smaller file sizes`: thanks to quantization (e.g., a 7B model in Q4_K_M is ~4GB instead of ~14GB in FP16).

> GGUF is the de facto standard for distributing open-source models(2026). Almost every major model on
> Hugging Face (Llama, Mistral, Gemma, Qwen, Phi, DeepSeek, etc.) has official GGUF conversions.

#### Explore GGUF metadata

In the gguf file, you can access the model metadata. For example with ollama you can view the model metadata

```shell
> ollama show gemma4:e4b

# expected output
  Model
    architecture        gemma4
    parameters          8.0B
    context length      131072
    embedding length    2560
    quantization        Q4_K_M
    requires            0.20.0

  Capabilities
    completion
    vision
    audio
    tools
    thinking

  Parameters
    temperature    1
    top_k          64
    top_p          0.95

  License
    Apache License
    Version 2.0, January 2004
    ...

```

`parameters: 8.0B` : This means the model has 8 Billion parameters (the internal weights and biases it learned during
training).

`context length 131072` : This is the model's maximum context window, measured in "tokens" (words or pieces of words).
131,072 tokens is equivalent to a 128K context window.
`It means the model can process roughly 100,000 words in a single prompt`

`embedding length 2560` : This is the hidden dimension of the model. When the model reads a word (token), it converts
it into a list of numbers (a vector) to understand its meaning. Every single token is represented internally as a list
of 2,560 floating-point numbers.

`quantization Q4_K_M` : describes the quantization rules which are used of the model

`Quantization` reduces the precision of model weights (from 16-bit floats down to fewer bits) to
`make models smaller, faster, and usable on consumer hardware`.

Quick Decision Guide

- Best quality possible → Q6_K or Q5_K_M
- Best balance → Q4_K_M (start here)
- Maximum speed + low memory → Q4_K_S or IQ4_XS
- Running 70B on 24–32 GB → Q3_K_M or IQ3_M
- Almost no quality loss → Q6_K / Q8_0

The difference between big and small quants is more noticeable in:

- Long context
- Complex reasoning
- Creative writing
- Instruction following

Less noticeable in simple chat or knowledge recall.

`requires: 0.20.0` : this indicates the minimum version of the `llama.cpp` software required to run this specific model
file