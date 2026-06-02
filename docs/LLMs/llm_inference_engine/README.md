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



## General architecture

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

## Inference engine workflow

Suppose user send a request via rest api of the llama.cpp web server. 

```python
from llama_cpp import Llama

# 1. Initialize the model with your exact context window sizes
llm = Llama(
    model_path="/var/lib/llama-models/Llama-3.gguf",
    n_ctx=16384,          # Expanded to fit large syslog payloads
    n_threads=8,          # Match your server CPU core availability
    verbose=False         # Disable dense internal token generation stats
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
    temperature=0.2,       # Low temperature to enforce analytical consistency
    max_tokens=2048       # Headroom for detailed markdown tables
)

# 4. Extract and print the Markdown response
print(response["choices"][0]["message"]["content"])
```

### Step 1. Load the Model file

The inference engine must load a model first. Suppose the model is packaged in a file like `Llama-3.gguf`(or `.safetensors`)

The model file usually contains:

- Attention weights
- FFN weights
- Embedding tables
- LayerNorm parameters

> llama.cpp also read model metadata to get prompt template and special tokens(e.g. <|begin_of_text|><|start_header_id|>system<|end_header_id|>)

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
specifically the `Decoder-only design`. When generating text, the model works `autoregressively`(it generates one token at a time.)

For every new token you want to generate, the model must compute `self-attention between the new token and all previous tokens`. 
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

The new generated token is appended to the previous content of the prompt to generate a `new prompt`. The new prompt will
restart the process until it meets:
- EOS token 
- Max length 
- Stop sequence