# Python api for llama.cpp

You can interact with llama.cpp directly via a python api.

## Install the api package

```shell
# in your virtual env, run 
pip install llama-cpp-python

# if you have a GPU(e.g. CUDA)
CMAKE_ARGS="-DGGML_CUDA=on" pip install llama-cpp-python
```

## Quick start

Suppose you have a model:

```text
models/
└── Qwen3-8B-Q4_K_M.gguf
```

```python
from llama_cpp import Llama

llm = Llama(
    model_path="models/Qwen3-8B-Q4_K_M.gguf",
    n_ctx=8192,
    n_threads=8,
    verbose=False
)

response = llm(
    "Explain Apache Spark in 3 paragraphs.",
    max_tokens=512,
    temperature=0.7
)

print(response["choices"][0]["text"])
```

## Create a chat

Similar to Ollama's chat interface, `llama.cpp` provides also a chat interface.

Below is an example

```python
from llama_cpp import Llama

llm = Llama(
    model_path="models/Qwen3-8B-Q4_K_M.gguf",
    chat_format="chatml"
)

response = llm.create_chat_completion(
    messages=[
        {
            "role": "system",
            "content": "You are a Spark expert."
        },
        {
            "role": "user",
            "content": "What is Spark?"
        }
    ]
)

print(response["choices"][0]["message"]["content"])
```

If you want to activate the stream capacity, use the `stream=true` option, below code is an example

```python
from llama_cpp import Llama

llm = Llama(
    model_path="models/Qwen3-8B-Q4_K_M.gguf"
)

stream = llm.create_chat_completion(
    messages=[
        {
            "role": "user",
            "content": "Write a Python quicksort implementation."
        }
    ],
    stream=True
)

for chunk in stream:
    delta = chunk["choices"][0]["delta"]

    if "content" in delta:
        print(delta["content"], end="", flush=True)
```

## Use embedding models

If you want to use an embedding model, you can follow the below example:

```python
from llama_cpp import Llama

model = Llama(
    model_path="models/nomic-embed-text.gguf",
    embedding=True
)

vector = model.create_embedding(
    "Apache Spark is a distributed data processing framework."
)

print(len(vector["data"][0]["embedding"]))
```