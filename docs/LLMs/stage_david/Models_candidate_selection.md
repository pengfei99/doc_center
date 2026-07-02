# Models candidates selection

To run the benchmark on models, we need to select some model candidates. The selection is based on 
- Base model
- fine-tuned model architecture (e.g. MOE)
- Base model parameters
- Active model parameter
- Quantization rules(Q4-K-M, etc)

## 1. Model fine-tuned architecture

In this section, the model architecture does not refer to the transformer architecture(e.g. encoder, decoder, etc.). It 
refers to :
- Mixture of Experts (MoE) Architecture
- Reasoning (Chain-of-Thought) Architecture
- Attention Architecture: MHA vs. GQA
- Instruct(Instruction Tuned)
- MTP(Multi-Token Prediction)

### 1.1. Mixture of Experts (MoE) Architecture


In a standard "dense" model (like Llama 3 8B), `every single word generated requires the CPU to read all 8 billion parameters from RAM`.

An `MoE model (like DeepSeek or Qwen MoE variants)` splits its internal layers into smaller subnetworks called "Experts." 
A central gatekeeper routing network directs each token to only 1 or 2 specific experts.

`The pros` (speed): An MoE model might have `35 Billion total parameters, but only 3.5 Billion active parameters per token`. 
For a CPU, this means it only has to pull 3.5GB worth of data from RAM per token, rather than 35GB. This results 
in exponentially faster token generation ($TG$) speeds compared to a dense model of equivalent intelligence.

`The cons` (RAM Bloat): The entire 35B model must still reside in your system RAM. While it speeds up token output, 
it demands a massive RAM footprint, limiting how much room you have left for large context windows or concurrent user slots.

> With MoE model, the active parameters will be max parameters to be loaded to the memory. 

### 1.2 Reasoning (Chain-of-Thought) Architecture

Models like `DeepSeek-R1` or `Phi-4-mini` are trained to generate an internal "thinking" process before writing an 
answer. Instead of outputting the final answer immediately, the model textually solves the problem step-by-step behind the scenes.

`The pros` (High Quality on Weak Hardware): It allows small models (like 4B or 8B) to solve complex enterprise problems 
that usually require giant 70B models. On a CPU server, running a "thinking" 4B model is infinitely faster 
than trying to run a dense 70B model.

`The Bad` (The Latency Multiplier): Because the model must generate hundreds of "thinking tokens" before providing 
the actual answer, the user has to wait longer for the final result. If a CPU is running at a slow 8 tokens/second, 
a response requiring 400 thinking tokens will force the user to wait nearly a full minute just to see the first sentence of the output.


### 1.3 Attention Architecture: `Multi-Head Attention (MHA)` vs. `Grouped-Query Attention (GQA)`

Inside the transformer architecture, the model uses an "Attention" mechanism to look back at previous words in the 
chat history. Older architectures used `Multi-Head Attention (MHA)`, while modern architectures use `Grouped-Query Attention (GQA)`.


The GQA Revolution: `GQA drastically reduces the size of the KV Cache` (the memory data structure that remembers the active conversation).

> For a CPU server, smaller KV Caches mean that when you enable multi-user concurrency (--parallel 4), the memory overhead 
> per user slot shrinks dramatically. This prevents your server from running out of RAM or clogging the CPU bus when multiple people are typing at the same time.
> 

### 1.4 Instruction Tuned model

A `base language model` is essentially just a giant auto-complete engine; if you type "How do I bake a cake?", a base model 
might just respond with a list of other questions like "How do I bake a pie? How do I cook a steak?" 

An Instruct model has `a secondary training phase called Instruction Fine-Tuning (IFT)`, often followed by `Reinforcement Learning (RLHF/RLAIF)`.

In the second phase, the model has been explicitly `trained to act as an assistant`. It `understands commands, follows system prompts, output formats` when asked, 
and carries out multi-turn conversations.

> If you are building an API server handling real users, you should almost always use "Instruct" models. 
> They are predictable, respect formatting constraints, and know how to stop generating text when the answer is complete.
> 
### 1.5 MTP (Multi-Token Prediction)

Traditional LLMs `predict one single token at a time`. `MTP` is a modern architectural paradigm 
(pioneered heavily by architectures like DeepSeek-V3/R1 and newer Qwen variants) where the 
`model is trained to predict multiple future tokens simultaneously` during its training phase.

It means the model's internal architecture is optimized to plan ahead and predict tokens $n+1$, $n+2$, etc., at the exact same time during its training.

> Even though the final GGUF file you run on your CPU usually only outputs one token at a time during standard inference, 
> an MTP-trained model has a much stronger grasp of sentence structure, grammar, and code logic because it was forced to "look ahead" during its training.

## Model parameters

The more parameters your model have, the more memory you need. If you don't have enough memory to load the model, the cpu
will need to switch model weights in memory. And the response time of your model will be slow. So choosing the right parameter
based on your hardware is essential.

### The Ultra-fast Tier (3B–5B)

With `3B–5B` parameters, the models runs incredibly fast on a standard CPU and leaves vast system 
RAM and cache overhead for processing long, simultaneous user chat histories

| Component                  | RAM Consumption   | Description                                                                                                                                                                         |
|----------------------------|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Model Weights (Static)     | ~3.0 GB – 3.2 GB  | The actual size of the GGUF file loaded into RAM.                                                                                                                                   |
| llama.cpp Runtime Overhead | ~0.2 GB – 0.5 GB  | Memory overhead for the `compute graph, thread synchronization, and OS subsystem handlers(e.g. memory mapping (mmap), system thread management,and the backend execution context)`. |
| KV Cache (Dynamic Buffer)  | ~0.1 GB – 1.5+ GB | The KV cache is used to accelerate conversational history computing. It `depends heavily on the context limit (-c) and user concurrency (--parallel)`.                              |

> For a GGUF file with `Q4_K_M` quantization, we need to reserve roughly 0.6 to 0.65 bytes per parameter. A model with `Q4_K_M` quantization
> stores quantizing attention tensors and some feed-forward weights at 4-bit, while keeping critical layers slightly higher to preserve model knowledge.

Below are some server config examples:

- Scenario A: A Single-User with llama.cpp config `--parallel 1, -c 8192 (8K context)`
    - Weights + Overhead: ~3.2 GB 
    - KV Cache Footprint: ~0.25 GB (for 8K context)
    - Total Allocation: ~3.5 GB of RAM

- Scenario B: Four users with llama.cpp config `--parallel 4 (4 concurrent slots), -c 8192 (8K context per slot)`
     - Weights + Overhead: ~3.5 GB
     - KV Cache Footprint: ~1.0 GB 
     - Total Allocation: ~4.5 GB of RAM

- Scenario C: 8 users with llama.cpp config `--parallel 8 (8 concurrent slots), -c 16384 (Large 16K context per slot)`
     - Weights + Overhead: ~4.5 GB 
     - KV Cache Footprint: ~2.0 GB 
     - Total Allocation: ~6.5 GB of RAM

### The Balanced Tier (7B–9B)

With `7B-9B` parameters, the models can solve complex reasoning, tool usage, and general chat. If after loading the model,
the system still have >2GB memory for handling user chat session. It can support multiple simultaneous users

| Component                  | RAM Consumption   | Description                                                                                                                                                                         |
|----------------------------|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Model Weights (Static)     | ~6.0 GB – 7.5 GB  | The actual size of the GGUF file loaded into RAM.                                                                                                                                   |
| llama.cpp Runtime Overhead | ~1 GB – 1.5 GB    | Memory overhead for the `compute graph, thread synchronization, and OS subsystem handlers(e.g. memory mapping (mmap), system thread management,and the backend execution context)`. |
| KV Cache (Dynamic Buffer)  | ~0.5 GB – 4.0+ GB | The KV cache is used to accelerate conversational history computing. It `depends heavily on the context limit (-c) and user concurrency (--parallel)`.                              |


Below are some server config examples:

- Scenario A: A Single-User with llama.cpp config `--parallel 1, -c 8192 (8K context)`
    - Weights + Overhead: ~6.3 GB 
    - KV Cache Footprint: ~0.25 GB (for 8K context)
    - Total Allocation: ~6.55 GB of RAM

- Scenario B: Four users with llama.cpp config `--parallel 4 (4 concurrent slots), -c 8192 (8K context per slot)`
     - Weights + Overhead: ~6.5 GB
     - KV Cache Footprint: ~1.0 GB 
     - Total Allocation: ~7.5 GB of RAM

- Scenario C: 8 users with llama.cpp config `--parallel 8 (8 concurrent slots), -c 16384 (Large 16K context per slot)`
     - Weights + Overhead: ~7.5 GB 
     - KV Cache Footprint: ~4.0 GB 
     - Total Allocation: ~11.5 GB of RAM

> with 1 user, the CPU may produce 10 tokens per second, but if we have 4 users at the same time, the server cpu will 
> bottleneck completely due to RAM bus saturation. Because cpu need to load kv cache of each user session from the memory
> and process them. You may have 1 token per second.

### The high-performance Tier (13B-120B+)

For models with more than 13B parameters(active), the `Core Bottleneck is Memory BUS Bandwidth`. The CPU does not 
spend its time doing math, it spends its time waiting for the model's parameters to travel from your system RAM into the CPU's cache.

To generate a single token, a 13B model at 4-bit quantization requires the CPU to read roughly `7.8 GB of data from your RAM`.

At a standard DDR4 or DDR5 memory bandwidth limit, `a single user` will typically experience an inference speed of roughly 4 to 7 tokens per second (t/s).

For a single user this speed is OK, but if we serve multiple users with an API, the speed will drop quickly. Below are some examples

| Concurrent Users (--parallel) | Average Speed Per User | User Experience             |
|-------------------------------|------------------------|-----------------------------|
| 1 User                        | ~6.0 tokens/sec        | Acceptable (Reading speed)  |
| 2 Users                       | ~3.0 tokens/sec        | Noticeable Lagging          |
| 4 Users                       | ~1.5 tokens/sec        | Frustrating / Timeout risks |

## Quantization


## Model name and metadata analysis

In general, the model name give you much information about the model. If it's not enough, you can go to the hugging-face
website to get more metadata of the model.






-          https://huggingface.co/empero-ai/Qwythos-9B-Claude-Mythos-5-1M-GGUF
-          https://huggingface.co/squ11z1/Mythos-nano  
-          https://huggingface.co/VLTX/VertaLily-1.2-1B-GGUF
-          https://huggingface.co/unsloth/Phi-4-mini-instructGGUF
-          https://huggingface.co/unsloth/gpt-oss-20b-GGUF
-          https://huggingface.co/TeichAI/Qwen3-14B-Claude-4.5-Opus-High-Reasoning-Distill-GGUF
-          https://huggingface.co/yuxinlu1/gemma-4-12B-it-Claude-4.6-4.8-Opus-GGUF
-          https://huggingface.co/google/gemma-4-12B-it-qat-q4_0-gguf
-          https://huggingface.co/Jackrong/Qwen3.5-9B-DeepSeek-V4-Flash-GGUF
-          https://huggingface.co/prism-ml/Bonsai-8B-gguf
-          https://huggingface.co/mistralai/Ministral-3-8B-Instruct-2512-GGUF

Spécialisés code :
-          https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF
-          https://huggingface.co/bartowski/DeepSeek-Coder-V2-Lite-Instruct-GGUF
-          https://huggingface.co/yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF
-          https://huggingface.co/jica98/qwen3.5-4B-super-coder

Spécialisés traduction :
-          https://huggingface.co/tencent/HY-MT1.5-1.8B-GGUF
-          https://huggingface.co/google/madlad400-3b-mt
-          https://huggingface.co/unsloth/Hy-MT2-7B-GGUF