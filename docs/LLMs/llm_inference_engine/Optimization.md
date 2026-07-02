# Optimization of inference engine runtime 

## kv cache quantization

With `llama.cpp`, we can also quantize the `KV cache`(conversation cache). For example with options like
`-ctk q8_0 -ctv q8_0`, we can store the `KV cache` at 8-bit precision instead of `16-bit` float. This can cut the 
`dynamic RAM footprint of your concurrent user slots` precisely in half with zero noticeable degradation in text quality.

