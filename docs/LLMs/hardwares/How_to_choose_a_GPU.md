# How to choose a GPU?

Let's start with the key parameters of a GPU

- Architecture: Blackwell vs Ada Lovelace
- Form Factor: SXM6 Baseboard (8 GPUs in 4U/8U chassis),PCIe Dual-Slot
- VRAM capacity: 
- VRAM Type: HBM3e vs GDDR6 vs GDDR7
- VRAM Bandwidth:
- Slot type: NVSwitch, PCIe
- Interconnect : NVLink Mesh, PCIe Gen5 with NVlink, PCIe Gen4 no NVLink
- Low-Precision AI: Native FP4 / FP8, or Native FP8 / FP16

## What is Low-Precision AI?

Traditionally, AI models were trained and run using `16-bit or 32-bit` floating-point numbers (FP16 or FP32). 
While precise, they consume massive amounts of memory and memory bandwidth. 

Low-precision AI compresses the parameter precision down to 8 bits (FP8) or even 4 bits (FP4). This cuts the required 
memory footprint in half (or quarters) and drastically accelerates data movement, which is the primary bottleneck in modern AI inference.

When you see a GPU says it supports `native FP4 and FP8 formats`, it means it is designed to support 4-bit and 8-bit float
math operations. The blackwell architecture supports native FP4 and FP8 formats

The older GPU architecture which does not support native FP4 has to `emulate low-precision math through software or slower mixed-precision paths`

### Which one is better:  FP4 vs FP8 vs FP 16?

In general, for standard chat, summarization, and retrieval tasks, `FP4 Wins`(When Using Blackwell Hardware), it outperforms `FP8 and FP16` in key areas:
- `Double the Throughput`: FP4 handles roughly twice the computational throughput of FP8, dramatically increasing tokens-per-second.
- `Massive Memory Savings`: Dropping from FP8 to FP4 cuts the model's memory footprint in half again. This allows massive models (like 70B or 400B parameter LLMs) to fit on significantly fewer GPUs.   
- `Near-Lossless Accuracy`: Older 4-bit formats (like basic INT4) heavily degraded model quality. Modern implementations like NVIDIA’s NVFP4 use clever two-level block scaling (micro-scaling), 
                          meaning the actual accuracy drop on benchmarks like MMLU is a negligible fraction of a percent.   


In some case, `FP8 or FP16 is "Better"`. For example:

- `Complex Reasoning and Multi-Step Logic`: For advanced chain-of-thought reasoning models (which perform long, multi-step math, coding, or complex logic), 
          the slight rounding errors in a 4-bit space can occasionally compound over long generation sequences, making FP8 a safer choice for high-stakes accuracy.
- `Ecosystem and Framework Maturity`: Old inference engine may not support FP4, because the legacy standard was FP8 and FP16.
- `Old Hardware limitation`: GPU such as H100 or H200 (Hopper architecture), do not have `native FP4 Tensor Cores`. 
           Trying to run FP4 on them requires software emulation, which completely destroys performance. On those systems, FP8 is the peak performance standard.
