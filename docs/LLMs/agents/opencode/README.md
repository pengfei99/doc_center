# What is OpenCode?

OpenCode is an open-source AI coding agent — a terminal app (TUI), desktop app, and IDE extension that reads your repo, runs commands, edits files, and talks to any LLM you point it at. Maintained by [Anomaly](https://github.com/anomalyco), MIT-licensed.

**Three things it does that a chat UI can't:**

- **Reads your actual repo** — not pasted snippets. Greps your files, follows imports, grounds answers in real context using built-in `read`/`grep`/`glob` tools.
- **Edits in place and runs your stack** — diff-aware `edit`/`write`/`apply_patch`, then `bash` to run your tests, linter, or build on the spot.
- **Composes with the rest of your toolchain** — multi-provider models, custom slash commands, agent skills, JS/TS plugins, MCP servers, LSP, formatters, and an HTTP server for CI use.

**Three interfaces:**

| Surface | Command | When |
|---|---|---|
| **TUI** (default) | `opencode` | Interactive day-to-day work in your terminal |
| **CLI / headless** | `opencode run "<prompt>"` | Scripts, CI jobs, one-shot prompts |
| **Server** | `opencode serve` or `opencode web` | Headless API, web UI, or remote attach |

```bash
opencode                                       # start TUI in the current repo
opencode run "fix the failing test in src/api.test.ts"
opencode serve --port 4096                     # headless server
```

> OpenCode sits in the same space as Claude Code, Cursor, and Aider — same problem, different trade-offs. None is universally better; pick the one whose model, surface, and ecosystem fit your workflow.

> ⚠️ **AI-coding caveat:** OpenCode (like every coding agent) can produce wrong code, miss edge cases, hallucinate APIs, and over-apply patterns. **You're still the reviewer.** Read diffs before accepting, run tests, and don't auto-approve destructive operations on code you care about.

---

### When OpenCode isn't the right tool

| Limitation | Detail |
|---|---|
| **No inline editor completion** | OpenCode is a conversational agent, not Copilot-style autocomplete. For ghost-text-while-you-type, reach for [Copilot](https://github.com/features/copilot), [Cursor Tab](https://cursor.sh/), [Codeium](https://codeium.com/), or [Supermaven](https://supermaven.com/) — or alongside. |
| **Quality depends on the underlying model** | OpenCode doesn't replace the LLM's reasoning. If your task fails on Sonnet, switching to OpenCode won't fix it. |
| **Provider-agnostic ≠ provider-equivalent** | Some models tool-call better than others. A slug swap isn't free. |
| **TUI on slow SSH / minimal terminals** | The TUI uses truecolor and complex layouts. Degrades over slow connections. `opencode serve` + `attach` or `opencode run` are better for those cases. |
| **Plugins run arbitrary code** | Any plugin — local or npm — has full user permissions. Audit before installing. |
| **Free Zen models are time-limited** | The [Zen docs](https://opencode.ai/docs/zen) call them "available for a limited time." Don't build production on them. |
| **Docs lag shipping** | OpenCode moves fast. This guide and even the official docs occasionally trail the actual binary. |
| **Not a substitute for code review** | Diff-aware edits + passing tests don't guarantee correct, secure, or maintainable code. Treat AI output as a junior teammate's PR. |

**When something else fits better:**

- Want a polished single-vendor product → **Claude Code** or **Cursor**.
- Deeply embedded in VS Code workflow → **Cursor** or **GitHub Copilot**.
- Want a small Python tool you can read end-to-end → **[Aider](https://aider.chat/)**.
- Don't want to manage provider keys → a managed hosted product.

> OpenCode's trade-off: flexibility and openness over polish and single-vendor integration. Worth it for many use cases; not all.

---