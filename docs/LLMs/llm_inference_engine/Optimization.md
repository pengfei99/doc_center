# Optimization of inference engine runtime 

## kv cache quantization

With `llama.cpp`, we can also quantize the `KV cache`(conversation cache). For example with options like
`-ctk q8_0 -ctv q8_0`, we can store the `KV cache` at 8-bit precision instead of `16-bit` float. This can cut the 
`dynamic RAM footprint of your concurrent user slots` precisely in half with zero noticeable degradation in text quality.


```shell
llama-server.exe \
  -m your-13b-model-q4_k_m.gguf \
  -c 4096 \
  -t 8 \
  -tb 8 \
  --parallel 2 \
  --flash-attn auto \
  -ctk q8_0 -ctv q8_0 \
  --port 8080
```

- `-c 4096` : Sets the global context window limit to 4,096 tokens (-c stands for --ctx-size).
- `-t 8`: Allocates exactly 8 threads for the text generation loop (-t stands for --threads).
- `-tb 8`: Allocates exactly 8 threads for prompt processing and parallel batch operations (-tb stands for --threads-batch). 
        While `-t` controls the speed of generating one word at a time, `-tb controls the speed of ingesting a large user prompt`
          (the "prefill" phase). Keeping this explicitly synced with your core allocation ensures that processing new prompts won't oversubscribe your CPU architecture.
- `--parallel 2`: Provisions exactly 2 active execution slots (-np or --parallel). This enables Continuous Batching. The server can hold conversations with 2 distinct users completely simultaneously. 
                   If a third user connects while both slots are busy, the server securely queues their request rather than dropping it or allowing performance to crash.
- `--flash-attn auto`: Forces the server to use an optimized implementation of the attention mechanism. 
                  This reduces computational overhead and drastically slashes memory utilization during the prompt ingestion phase. 
                 For multi-user API servers, this prevents memory-hungry request spikes from bogging down the host operating system.
- `-ctk q8_0 -ctv q8_0`: compress the kv cache to 8-bit
