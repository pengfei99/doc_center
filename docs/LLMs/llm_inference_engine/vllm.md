# Introduction of vLLM

`vLLM` is a fast and easy-to-use library for `LLM inference and serving`. While `llama.cpp` is optimized for 
CPU/low-VRAM efficiency and single-user scenarios, `vLLM is the industry standard for high-throughput, 
multi-user production workloads on enterprise GPUs`.


You can find their official website [here](https://vllm.ai/) and github page [here](https://github.com/vllm-project/vllm)

## vLLM key features

Compare to other inference engine(e.g.), vLLM has the below feature:
- `efficient KV cache management`: Instead of treating the KV cache as one rigid block, vLLM utilizes `PagedAttention`, 
             which manages memory exactly like an Operating System's virtual memory—breaking the KV cache into pages to 
             eliminate fragmentation and unlock massive concurrent batching.
- `Continuous batching of incoming requests, chunked prefill, prefix caching`
- Quantization: FP8, MXFP8/MXFP4, NVFP4, INT8, INT4, GPTQ/AWQ, GGUF, compressed-tensors, ModelOpt, TorchAO, and more
- Disaggregated prefill, decode, and encode