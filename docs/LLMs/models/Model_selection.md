# How to choose a model?


| Model               | Size Range | Best Fit Task               | VRAM Needed (Q4/FP8) | Primary Engines  |
|---------------------|------------|-----------------------------|----------------------|------------------|
| gpt-oss             | 20B – 120B | Reasoning & Agents          | ~14 GB – 80 GB       | vLLM / llama.cpp |
| Gemma 4             | 2B – 31B   | Multimodal & Fast Chat      | ~4 GB – 20 GB        | llama.cpp / vLLM |
| Qwen 3.8 / 3.5      | 4B – 35B+  | Coding & Multilingual       | ~6 GB – 24 GB+       | vLLM / llama.cpp |
| DeepSeek R1 Distill | 14B – 70B  | Math & Logic Reasoning      | ~10 GB – 42 GB       | llama.cpp / vLLM |
| Llama 3.3           | 70B        | General Assistant & Writing | ~40 GB – 48 GB       | vLLM / llama.cpp |


| Model         | Size      | Best Precision on 96GB | Tokens/sec Target | Ideal Use Case                            |
|---------------|-----------|------------------------|-------------------|-------------------------------------------|
| gpt-oss-120b  | 120B      | FP8 / Q4_K_M           | ~30 – 45 t/s      | "Agents, Logic, Structured JSON"          |
| DeepSeek R1   | 671B MoE  | NVFP4 / IQ4_XS         | ~25 – 40 t/s      | "Complex Math, Algorithm Design"          |
| Llama 3.3 70B | 70B Dense | Native FP8             | ~65 – 90 t/s      | "Multi-user Chat API, High Concurrency"   |
| Gemma 4 31B   | 31B Dense | Unquantized FP16       | ~110+ t/s         | "Low latency, Vision + Audio processing"  |
| Qwen 3.8 27B  | 27B Dense | Unquantized FP16       | ~120+ t/s         | "Extreme speed repo coding, 256k context" |



> We need to test the 