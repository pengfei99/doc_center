# Models candidates selection

To run the benchmark on models, we need to select some model candidates. The selection is based on 
- Base model
- fine-tuned model architecture (e.g. MOE)
- Base model parameters
- Active model parameter
- Quantization rules(Q4-K-M, etc)

## Model architecture

In this section, the model architecture does not refer to the transformer architecture(e.g. encoder, decoder, etc.). It 
refers to :
- Mixture of Experts (MoE) Architecture
- Reasoning (Chain-of-Thought) Architecture
- Attention Architecture: MHA vs. GQA

### Mixture of Experts (MoE) Architecture


In a standard "dense" model (like Llama 3 8B), `every single word generated requires the CPU to read all 8 billion parameters from RAM`.

An `MoE model (like DeepSeek or Qwen MoE variants)` splits its internal layers into smaller subnetworks called "Experts." 
A central gatekeeper routing network directs each token to only 1 or 2 specific experts.

`The pros` (speed): An MoE model might have `35 Billion total parameters, but only 3.5 Billion active parameters per token`. 
For a CPU, this means it only has to pull 3.5GB worth of data from RAM per token, rather than 35GB. This results 
in exponentially faster token generation ($TG$) speeds compared to a dense model of equivalent intelligence.

`The cons` (RAM Bloat): The entire 35B model must still reside in your system RAM. While it speeds up token output, 
it demands a massive RAM footprint, limiting how much room you have left for large context windows or concurrent user slots.

> With MoE model, the active parameters will be max parameters to be loaded to the memory. 

### Reasoning (Chain-of-Thought) Architecture

Models like `DeepSeek-R1` or `Phi-4-mini` are trained to generate an internal "thinking" process before writing an 
answer. Instead of outputting the final answer immediately, the model textually solves the problem step-by-step behind the scenes.

`The pros` (High Quality on Weak Hardware): It allows small models (like 4B or 8B) to solve complex enterprise problems 
that usually require giant 70B models. On a CPU server, running a "thinking" 4B model is infinitely faster 
than trying to run a dense 70B model.

`The Bad` (The Latency Multiplier): Because the model must generate hundreds of "thinking tokens" before providing 
the actual answer, the user has to wait longer for the final result. If a CPU is running at a slow 8 tokens/second, 
a response requiring 400 thinking tokens will force the user to wait nearly a full minute just to see the first sentence of the output.


### Attention Architecture: `Multi-Head Attention (MHA)` vs. `Grouped-Query Attention (GQA)`

Inside the transformer architecture, the model uses an "Attention" mechanism to look back at previous words in the 
chat history. Older architectures used `Multi-Head Attention (MHA)`, while modern architectures use `Grouped-Query Attention (GQA)`.


The GQA Revolution: `GQA drastically reduces the size of the KV Cache` (the memory data structure that remembers the active conversation).

> For a CPU server, smaller KV Caches mean that when you enable multi-user concurrency (--parallel 4), the memory overhead 
> per user slot shrinks dramatically. This prevents your server from running out of RAM or clogging the CPU bus when multiple people are typing at the same time.
> 


## Model parameters

### The Ultra-Efficient Tier (3B–5B)

With `3B–5B` parameters, the models runs incredibly fast on a standard CPU and leaves vast system 
RAM and cache overhead for processing long, simultaneous user chat histories

### The Balanced Tier (7B–9B)


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