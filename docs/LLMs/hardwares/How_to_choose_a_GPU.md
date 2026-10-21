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

- `Complex Reasoning and Multi-Step Logic`: For advanced chain-of-thought reasoning models (which perform long, multistep math, coding, or complex logic), 
          the slight rounding errors in a 4-bit space can occasionally compound over long generation sequences, making FP8 a safer choice for high-stakes accuracy.
- `Ecosystem and Framework Maturity`: Old inference engine may not support FP4, because the legacy standard was FP8 and FP16.
- `Old Hardware limitation`: GPU such as H100 or H200 (Hopper architecture), do not have `native FP4 Tensor Cores`. 
           Trying to run FP4 on them requires software emulation, which completely destroys performance. On those systems, FP8 is the peak performance standard.

## CUDA core vs Tensor core vs RT core

Inside an NVIDIA GPU, you have three types of computation cores:
- CUDA cores: flexible, general-purpose parallel processor, it supports high precision (FP32, FP64), it can execute virtually any custom algorithm
- Tensor cores: specialized Matrix math accelerators built strictly for speed in AI workloads. It ofen support low precision  (FP4, FP8). Strictly optimized for grid/matrix math
- RT cores: handle the mathematical calculations required for `ray tracing` that simulates how light bounces, reflects, refracts, and casts shadows in a virtual 3D environment. **Useless for LLMs reference**

In general, to run a model LLMs, the GPU uses both cores:
- CUDA cores handle data preprocessing, tokenization, formatting, and routing.
- Tensor cores crunch the neural network's weights to generate text tokens.

> Ignore RT cores, if you use GPU only for LLMs.

## Conflict between model precision and GPU precision.

In general, the standard uncompressed weights of LLMs from HF are FP16. For example, for gemma-4, you can check the
[config.json](https://huggingface.co/google/gemma-4-31B-it/blob/main/config.json), you will find rows such as `"dtype": "bfloat16"`.

As you can notice, the blackwell architecture 

## NVIDIA RTX PRO 6000 (Blackwell) server edition

You can find the official product spec page [here](https://www.nvidia.com/en-us/data-center/rtx-pro-6000-blackwell-server-edition/)

### Compute Performance

| Parameter        | Value                |
|------------------|----------------------|
| GPU Architecture | Blackwell            |
| CUDA Cores       | 24,064               |
| Tensor Cores     | 752 (5th Generation) |

For LLMs single-precision weights operation, the performance is like:

| Precision | Core type   | Speed (Floating-Point Operations per second) |
|-----------|-------------|----------------------------------------------|
| FP4       | Tensor Core | 4 Peta                                       |
| FP8 	     | Tensor Core | 2 Peta                                       |
| FP16      | Tensor Core | 1 Peta                                       |
| FP32      | Tensor Core | 234 Tera                                     |


> For standard math Single-Precision FP32, the speed is 120 Floating-Point Operations per second(120 trillion operation/s).                                         |

### Memory & Interconnect

Memory type: GDDR7 with Error Correction Code
Memory Capacity:	96 GB 
Memory Interface	512-bit
Memory Bandwidth	1597 GB/s

### Virtualization

It supports `hardware-level virtualization(MIG)`, which guarantee the complete isolation of processing power(e.g. CUDA cores, Tensor Cores), 
memory size and bandwidth.

Many slicing is possible:
- maximum 4 instance of 24GB
- 1 48GB and 2 24GB
- 2 48GB

### Slot type

PCI Express 5.0 x16 with NVLink support


## NVIDIA L40S

### Compute Performance

| Parameter        | Value                |
|------------------|----------------------|
| GPU Architecture | Ada Lovelace         |
| CUDA Cores       | 18,176               |
| Tensor Cores     | 568 (4th Generation) |

For LLMs single-precision weights operation, the performance is like (incorporating 2:4 structured sparsity where applicable):

| Precision | Core type   | Speed (Floating-Point Operations per second) |
|-----------|-------------|----------------------------------------------|
| FP4       | Tensor Core | Not Supported                                |
| FP8 	     | Tensor Core | 733 Tera                                     |
| FP16      | Tensor Core | 366 Tera                                     |
| FP32      | Tensor Core | 183 Tera                                     |


> For standard math Single-Precision FP32, the speed is 91.6 Tera Floating-Point Operations per second (91.6 trillion operations/s).

### Memory & Interconnect

Memory type: GDDR6 with Error Correction Code (ECC)

Memory Capacity: 48 GB

Memory Interface: 384-bit

Memory Bandwidth: 864 GB/s   

### Virtualization

It does not support hardware-level Multi-Instance GPU (MIG) partitioning. Instead, it relies on 
standard software-based NVIDIA vGPU profiles or container-level isolation if shared across multiple workloads.

### Slot type

PCI Express 4.0 x16 (No NVLink support)


| Parameter / Feature                    | NVIDIA L40S                                       | NVIDIA RTX Pro 6000 (Blackwell) Server Edition                               |
|----------------------------------------|---------------------------------------------------|------------------------------------------------------------------------------|
| GPU Architecture                       | Ada Lovelace                                      | Blackwell                                                                    |
| CUDA Cores                             | "18,176"                                          | "24,064"                                                                     |
| Tensor Cores                           | 568 (4th Gen)                                     | 752 (5th Gen)                                                                |
| FP4 Tensor Compute                     | Not Supported                                     | 4.0 PFLOPS                                                                   |
| FP8 Tensor Compute                     | 733 TFLOPS                                        | 2.0 PFLOPS                                                                   |
| FP16 / BF16 Tensor Compute             | 366 TFLOPS (Dense)                                | 1.0 PFLOP                                                                    |
| FP32 Tensor Compute                    | 183 TFLOPS                                        | 234 TFLOPS                                                                   |
| Standard Single-Precision (FP32)       | 91.6 TFLOPS                                       | 120.0 TFLOPS                                                                 |
| Memory Type                            | GDDR6 with ECC                                    | GDDR7 with ECC                                                               |
| Memory Capacity                        | 48 GB                                             | 96 GB                                                                        |
| Memory Interface                       | 384-bit                                           | 512-bit                                                                      |
| Memory Bandwidth                       | 864 GB/s                                          | "1,597 GB/s"                                                                 |
| Virtualization Support                 | No MIG (Software vGPU / Container isolation only) | Multi-Instance GPU (MIG)• Max 4 instances x 24GB• 1x 48GB + 2x 24GB• 2x 48GB |
| PCIe Interface                         | PCI Express 4.0 x16 (No NVLink)                   | PCI Express 5.0 x16                                                          |
| Power Consumption (TDP)                | 350 W                                             | 600 W                                                                        |
| Approx. France Price (TTC / Incl. Tax) | "~11,400 € – 12,800 € TTC"                        | "~18,500 € – 21,000 € TTC"                                                   |