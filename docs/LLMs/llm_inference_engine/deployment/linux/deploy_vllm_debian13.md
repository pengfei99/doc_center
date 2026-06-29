# Deploy vLLM on debian 13

vLLM provides many backend to support different types of hardware. The best way is to go to the [vLLM website](https://vllm.ai/)
and follow the official instructions.

## Use uv to install vLLM on CPU only server

The easiest way is to install the pre-build versions via uv. Below is an command example

```shell
# create a virtual env
uv venv vllm-bench-cpu --python 3.14
source vllm-bench-cpu/bin/activate

# Install dependencies and the CPU-specific vLLM build
pip install --upgrade pip
# install the pre-build bin with torch backend on cpu
uv pip install vllm --extra-index-url https://wheels.vllm.ai/0.23.0/cpu --torch-backend cpu
```

If you want to build your own vLLM, you can find more detailed docs [here](https://docs.vllm.ai/en/v0.6.6/getting_started/cpu-installation.html)
For Intel cpu/gpu, you can use a special backend called `OpenVINO`, it should offer better performance. You can find the doc [here](https://docs.vllm.ai/en/v0.6.6/getting_started/openvino-installation.html)


### CPU Environment Tuning


On a GPU, thousands of small compute cores process matrix multiplications natively. On a CPU, vLLM relies on `OpenMP threads`. 
If you don't restrict and bind these threads, your CPU cores will spend all their time context-switching, 
grinding your inference speed to a halt.

Set up the below env vars in your terminal before launching the server:
```shell
# 1. Allocate space (in GB) for the PagedAttention KV Cache in system RAM
export VLLM_CPU_KVCACHE_SPACE=16

# 2. Bind OpenMP threads directly to your physical CPU cores.
# For example, if you have an 8-Core/16-Thread CPU, restrict it to the first 8 physical cores:
export VLLM_CPU_OMP_THREADS_BIND=0-7
```

https://docs.vllm.ai/en/latest/getting_started/installation/cpu/

```shell
# install TCMalloc, Intel OpenMP is installed with vLLM CPU
sudo apt-get install -y --no-install-recommends libtcmalloc-minimal4

# manually find the path
sudo find / -iname *libtcmalloc_minimal.so.4
sudo find / -iname *libiomp5.so

# 
TC_PATH=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
IOMP_PATH=/home/pliu/git/test-vllm/vllm-bench/lib/libiomp5.so
```
### Use hugginf face repo id

```shell
meta-llama/Llama-3.2-3B-Instruct
```
### Use GGUF file

When I use vllm to deploy a model in gguf format with the below command, I encounter errors 

```shell
vllm serve /var/lib/llama-models/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf \
    --quantization gguf \
    --tokenizer Qwen/Qwen3-Coder-30B-A3B-Instruct \
    --hf-config-path Qwen/Qwen3-Coder-30B-A3B-Instruct \
    --port 8000 \
    --max-model-len 32768
```

This error is caused by `vLLM's experimental GGUF parser` does not know how to map MoE expert weight keys (like mlp.experts.gate_up_proj) 
back into `PyTorch tensors`. It expects dense models, so it hits a hard crash during the weight-mapping phase.

```text
RuntimeError: Failed to map GGUF parameters (48): ['model.layers.0.mlp.experts.gate_up_proj', 'model.layers.1.mlp.experts.gate_up_proj',
```