# Use uv

https://github.com/pengfei99/uv_tutorial

## Use ollama

Ollama is a framework that allows you to run `Large Language Models (LLMs)` locally on your computer. It simplifies:

- Downloading models
- Running inference
- Managing model versions
- Creating custom models
- Exposing models through an OpenAI-compatible API

### quick starts

```shell
# check if ollama exists
ollama --version

# list existing models
ollama list

# show the model details
ollama show gemma4:e4b

# run the model
ollama run gemma4:e4b

# download a model
ollama pull qwen3:4b

# delete a model
ollama rm qwen3:4b
```


### Model search engine

Ollama does not provide a CLI to search models, but it offers a web application https://ollama.com/search


### python API

```shell
pip install ollama
```

```python
from ollama import chat

response = chat(
    model="llama3.3",
    messages=[
        {
            "role": "user",
            "content": "Explain Apache Spark"
        }
    ]
)

print(response["message"]["content"])
```