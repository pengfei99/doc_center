# Models candidates selection

To run the benchmark on models, we need to select some model candidates. The selection is based on 
- Base model architecture (e.g. MOE)
- Base model parameters
- Quantization rules(Q4-K-M, etc)

## Model architecture

In this section, the model architecture does not refer to the transformer architecture(e.g. encoder, decoder, etc.). It 
refers to :
- Mixture of Experts (MoE) Architecture
- Reasoning (Chain-of-Thought) Architecture
- Attention Architecture: MHA vs. GQA