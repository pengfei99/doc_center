# LLMs applications

 It is practically impossible to list every single LLMs application. In this section, we can categorize the landscape 
 into a comprehensive taxonomy.
 

## 1. Research & Scientific Discovery

The applications of this category help researchers process vast amounts of literature, generate hypotheses, and 
structure data, for example:
- `Literature Review & Synthesis`: Extracting findings from thousands of PDFs, finding contradictions in papers, and mapping citation networks.
                            Example apps: `AnythingLLM` or `Open WebUI` paired with a local document parser (like Nougat or Marker) and a Vector DB. 
- `Writing contents`: Drafting documents, formatting citations, etc.
- `Data Extraction from Unstructured Text`: Turning clinical trial PDFs or lab notes into structured JSON/CSV formats. 
        Example apps: `LlamaIndex` or `Haystack`.

## 2. Software Engineering & Coding

The applications of this category help developpeur to generate, test and review codes:

- `Code Autocomplete & Generation`: Inline suggestions and boilerplate generation. Cloud example: `GitHub Copilot, Cursor, Tabnine`. 
            self-hosted example: llama.ccp + Qwen2.5-Coder + Vscode + plugin(Continue.dev, Twinny).
- `Code Review & Security Scanning`: Analyzing pull requests for logic flaws, vulnerabilities, and style violations. Cloud example: `Sourcery, CodeRabbit, Snyk DeepCode`.
                  self-Hosted example: Custom agents using Semgrep + Local LLMs.
- `Code Translation`: Converting language A to B, or migrating between framework versions.

## 3. Enterprise Knowledge Management & Search

This is often the first internal tool a datacenter builds to break down "silos" of information.

- `Enterprise Search engine (RAG)`: "Chatting" with internal wikis, Confluence pages, SharePoint, and docs. Cloud example: Glean, Microsoft Copilot (M365), Guru.
self-Hosted example: `Dify, Langflow, Flowise` (these are visual LLM app builders you can host locally).
- `Meeting Summarization & Action Items`: Transcribing internal audio and extracting tasks. Cloud example: `Otter.ai, Fathom, Fireflies`.
self-Hosted example: Local Whisper (for transcription) + Local LLM (for summarization).

## 4. Data Analysis & Business Intelligence (BI)

Bridging the gap between non-technical researchers/stakeholders and complex databases.

- `Text-to-SQL`: Allowing users to ask "Show me the error rates of Experiment X over the last month" and generating the SQL query automatically. 
Cloud example: `ThoughtSpot, Databricks AI/BI, Tableau Pulse`. 
self-Hosted example: Vanna AI (open-source Text-to-SQL agent) or SQLChat.
- `Automated Data Cleaning`: Generating Python/Pandas scripts to clean messy CSVs based on natural language instructions.
Cloud example: Julius AI, Hal9.
self-Hosted example: `OpenInterpreter` (running locally in a secure sandbox).

## 5. Compliance & Security

Translating millions of lines logs or SIEM alerts into plain-English incident summaries.
SaaS Leaders: CrowdStrike Charlotte AI, Microsoft Security Copilot.
Self-Hosted Equiv: Elastic Security AI Assistant (can be configured with local models).

## 6. Customer Support & Service (IT Helpdesk)

- Ticket Deflection: Answering "How do I connect to my Box?" or "How do I export data?"
SaaS Leaders: Intercom Fin, Zendesk AI, Ada.
Self-Hosted Equiv: `Chatwoot or Zammad` integrated with local LLMs.


## 7. Agentic & Autonomous Systems (The Frontier)

The `Agentic systems` that can plan and execute multistep workflows and act on its own.
For example:
- Deep Research Agents: An agent that takes a prompt ("Find the linux server inventory"), searches PDFs, wiki, websites, 
cross-check the results, and outputs a report. `AutoGen, CrewAI, LangGraph (all can be hosted locally)`.
- Personal OS Assistants: Agents that can read local emails, draft replies, schedule calendar events, and organize files.

> Not easy to secure when working with confidential data, lack of control on agent actions.