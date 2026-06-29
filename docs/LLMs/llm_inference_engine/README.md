# LLM Inference Engine

A `LLM inference engine` is the software responsible for executing a `trained LLM model` and generating outputs
from inputs.

During the training of the LLM models, the weights in the neuron network are adjusted. The job of inference engine:

1. Load model weights
2. Tokenize input
3. Execute transformer computations
4. Generate tokens
5. Covert tokens to text, then return text

Examples of inference engines:

- llama.cpp
- vLLM
- TensorRT-LLM
- Text Generation Inference (TGI)
- SGLang

## 1. General architecture

Internal Components of a Modern Inference Engine

```text
Inference Engine
│
├── Model Loader
├── Tokenizer
├── Transformer Executor
├── Memory Manager
├── KV Cache Manager
├── Sampler
├── Scheduler
├── API Server
└── GPU Backend

```

## Inference engine workflow

A modern inference engine workflow looks roughly like:

```text
                    User Prompt
                          │
                          ▼
                  Tokenization Layer
                          │
                          ▼
                   Embedding Layer
                          │
                          ▼
                  Transformer Engine
                          │
            ┌─────────────┴─────────────┐
            │                           │
            ▼                           ▼
       KV Cache                  Sampling Engine
            │                           │
            └─────────────┬─────────────┘
                          ▼
                    Output Token
                          │
                          ▼
                   Detokenization
                          │
                          ▼
                      Text Output
```

Suppose user send a request via rest api of the llama.cpp web server.

```python
from llama_cpp import Llama

# 1. Initialize the model with your exact context window sizes
llm = Llama(
    model_path="/var/lib/llama-models/Llama-3.gguf",
    n_ctx=16384,  # Expanded to fit large syslog payloads
    n_threads=8,  # Match your server CPU core availability
    verbose=False  # Disable dense internal token generation stats
)

# 2. Read your target syslog file dynamically
with open("/tmp/syslog", "r") as f:
    log_data = f.read()

# 3. Format the payload using structured Roles
response = llm.create_chat_completion(
    messages=[
        {
            "role": "system",
            "content": (
                "Role:\n"
                "You are a senior cybersecurity analyst.\n\n"
                "Context:\n"
                "The organization uses Hadoop and Kerberos."
            )
        },
        {
            "role": "user",
            "content": (
                "Task:\n"
                "Analyze the provided logs.\n\n"
                "Requirements:\n"
                "- Identify anomalies\n"
                "- Explain root causes\n"
                "- Provide remediation steps\n\n"
                "Output:\n"
                "Markdown table\n\n"
                f"Logs:\n{log_data}"
            )
        }
    ],
    temperature=0.2,  # Low temperature to enforce analytical consistency
    max_tokens=2048  # Headroom for detailed markdown tables
)

# 4. Extract and print the Markdown response
print(response["choices"][0]["message"]["content"])
```

### Step 1. Load the Model file

The inference engine must load a model first. Suppose the model is packaged in a file like `Llama-3.gguf`(or
`.safetensors`)

The model file usually contains:

- Attention weights
- FFN weights
- Embedding tables
- LayerNorm parameters

> llama.cpp also read model metadata to get prompt template and special tokens(e.g. <|begin_of_text|><|start_header_id|>
> system<|end_header_id|>)

### Step 2. Tokenization

When the engine receives the user prompt, the engine convert text to token IDs

### Step3. Embedding lookup

After tokenization, each token ID is converted into a vector.

### Step4. Transformer engine execution

In this step, the engine repeats many times the below compute:

```text
Input
 ↓
Self Attention
 ↓
Feed Forward Network
 ↓
Output
```

For example

| Model       | Layers(repeat times) |
|-------------|----------------------|
| Llama 3 8B  | 32                   |
| Llama 3 70B | 80                   |
| Qwen3 32B   | 64+                  |

> Self Attention compute `Attention(Q,K,V)` for every token. The `attention` determines which previous tokens matter.
>

### Step5. KV cache

As we mentioned before, LLMs (e.g. Llama, Mistral, Gemma, etc.) are based on the `Transformer architecture`,
specifically the `Decoder-only design`. When generating text, the model works `autoregressively`(it generates one token
at a time.)

For every new token you want to generate, the model must compute
`self-attention between the new token and all previous tokens`.
This means it has to `re-process the entire conversation history` from the beginning every single time.

`KV Cache (Key-Value Cache)` is a clever optimization where the model stores the Key and Value vectors for every
token it has already processed.

In a transformer layer, attention is calculated using three matrices:

- Query (Q) — from the current token
- Key (K) — from all previous tokens
- Value (V) — from all previous tokens

Instead of recalculating K and V for past tokens every time, the model caches them.

So on the next step, it only computes:

- New Query for the latest token
- Then does attention between the new Query and all the cached Keys + Values.

Modern inference engines split generation into two phases:

- `Prefill Phase`: Process the entire prompt at once → compute and save all Keys & Values into KV Cache.
- `Decode Phase`: Generate tokens one by one -> use the KV Cache (this is where the big speedup happens).

> Without KV Cache, the decode phase would be painfully slow.
>
> The downside of KV Cache is that it consumes so much memory.
> For every token in the prompt, we need to `store kv cache of all layers`. For example, if the model has 32 layer, for
> one token, we need to store 32 times kv cache.
>

### Step 6. Logits Generation

After the last transformer layer, an output vector(e.g. 4096 dimensions vector) will be generated. This vector will be
projected to the vocabulary, which will be a list of logits:

- Paris: 15.2
- London: 4.1
- Pizza: -8.3

### Step 7. Sampling engine

We know in step6, we don't directly output a word, but a list of logits(token with probabilities).

The sampling engine applies parameters such as:

- Temperature
- Top-k
- Top-p
- Repetition penalty

to choose the best fit of the next word.

### Step 8. Iterative Generation

The new generated token is appended to the previous content of the prompt to generate a `new prompt`. The new prompt
will
restart the process until it meets:

- EOS token
- Max length
- Stop sequence

> When the token generation stops, the token will be converted to text and send back to users.
>

## Llama.cpp

You can check this [doc](./llama_cpp.md) to know more about llama.cpp(e.g architecture)

This [doc](./deployment/deploy_llamacpp_debian13.md) shows how to deploy llama.cpp on debian server.

## vllm

You can check this [doc](./vllm.md) to know more about vllm(e.g architecture)

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

## What Makes a Good Inference Engine?

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
| GGUF                      | llama.cpp                              | General LLM inference for CPU                                  | Best quantization, ecosystem support                                                                           | -                                         | Dominant standard   |
| Safetensors(Hugging Face) | vLLM                                   | Training + inference                                           | Very safe, fast loading, popular                                                                               | Usually FP16/BF16 (large files)           | Extremely popular   |
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

## Quantization Algorithms

| Format Class | Flag Identifier | Optimal Target Hardware Backend | Notes                                                                               |
|--------------|-----------------|---------------------------------|-------------------------------------------------------------------------------------|
| AWQ          | awq             | NVIDIA GPUs / Intel CPUs        | "High throughput, great multi-user scaling."                                        |
| GPTQ         | gptq            | NVIDIA GPUs / Intel CPUs        | Classic 4-bit standard.                                                             |
| Marlin       | marlin          | NVIDIA GPUs (Ampere+)           | A hyper-fast kernel wrapper for specialized 4-bit configurations.                   |
| FP8          | fp8             | "NVIDIA (Ada/Hopper/Blackwell)  | AMD (MI300+), Near-zero accuracy loss. Highly efficient for newer architectures.    |
| BitsAndBytes | bitsandbytes    | NVIDIA GPUs                     | "Supports 4-bit (nf4/fp4) and 8-bit on the fly. Slower, but retains high accuracy." |
| GGUF         | gguf            | NVIDIA GPUs / AMD GPUs          | Experimental. Requires external tokenizers.                                         |
| TorchAO      | torchao         | CPU / GPU                       | Uses PyTorch's native architecture optimization formats (INT8/INT4 dynamic).        |

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

`quantization Q4_K_M` : describes the quantization techniques of the model

`Quantization` reduces the precision of model weights (from 16-bit floats down to fewer bits) to
`make models smaller, faster, and usable on consumer hardware`.

Popular Quantization types comparison:

| Quant Type | Approx. Bits | Size (7B model) | Quality Loss (PPL Δ) | Speed     | Recommendation                    |
|------------|--------------|-----------------|----------------------|-----------|-----------------------------------|
| Q2_K       | ~2.7         | ~2.7 GB         | High                 | Fast      | Only for extreme memory limits    |
| IQ3_S      | ~3.4         | ~3.0 GB         | Medium-High          | Medium    | Good aggressive 3-bit             |
| IQ3_M      | ~3.6         | ~3.2 GB         | Medium               | Medium    | Best 3-bit option                 |
| Q3_K_M     | ~3.9         | ~3.1 GB         | Medium               | Fast      | Decent 3-bit K-quant              |
| Q4_K_S     | ~4.3         | ~3.6 GB         | Low-Medium           | Very Fast | Tight VRAM                        |
| Q4_K_M     | ~4.5–4.8     | ~3.8 GB         | Very Low             | Very Fast | Sweet spot for most users         |
| IQ4_XS     | ~4.25        | ~3.7 GB         | Very Low             | Medium    | Excellent quality/size            |
| Q5_K_S     | ~4.9         | ~4.3 GB         | Very Low             | Fast      | High quality                      |
| Q5_K_M     | ~5.1         | ~4.45 GB        | Extremely Low        | Fast      | Best balance of quality           |
| Q6_K       | ~6.0         | ~5.15 GB        | Almost none          | Medium    | Near-lossless                     |
| Q8_0       | 8.0          | ~6.7–7 GB       | Negligible           | Slower    | Maximum quality (still quantized) |

When to Choose Which One?

1. Q4_K_M — The Community Sweet Spot (2026)

    - Best overall choice for most people.
    - Excellent quality/size ratio.
    - Runs well on 6–8 GB VRAM GPUs (or CPU).
    - Minimal noticeable degradation on chat, coding, reasoning.

2. Q5_K_M or Q5_K_S

    - Choose this when you want noticeably better quality (especially reasoning, creativity, instruction following).
    - Still very good compression (~65–70% smaller than FP16).

3. Q4_K_S or IQ4_XS

    - When you are tight on memory (e.g. 5–6 GB VRAM or running large context).
    - IQ4_XS often beats Q4_K_S in quality at similar size.

4. IQ3_M / Q3_K_M

    - For running bigger models (13B–34B) on limited hardware.
    - IQ3_M is generally preferred over Q3_K_M at similar size.

5. Q6_K or Q8_0

    - When quality is critical (e.g. professional use, math, complex tasks).
    - Q6_K is very close to original model for most users.

6. I-Quants (IQ)*

    - Best when pushing very low bit counts (2–4 bits).
    - Use importance matrix -> smarter allocation of bits to important weights.

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