# Building Knowledge Graphs from Text with Julia & LLMs

A 90-minute introductory workshop in the style of [The Carpentries](https://carpentries.org/).

## Event

| | |
|---|---|
| **Dates** | March 12th – March 14th 2026 |
| **Event** | Spring School — *Teaching for Change: Sustainability in Language Education* |
| **Venue** | TU Braunschweig |
| **Workshop** | *How to deal with futures we do not know yet? Diversity-sensitive instruction in subject-specific teaching* |

## Overview

Unstructured text is everywhere — reports, articles, technical documentation — but extracting structured knowledge from it is hard.
In this hands-on workshop you will use **Julia** and a **Large Language Model (LLM)** to pull entities and relationships out of a small text corpus and assemble them into a **knowledge graph** you can query and visualise.

No prior programming or AI experience is required.

## Learning Objectives

By the end of this workshop you will be able to:

1. **Explain** what a knowledge graph is and where it is useful.
2. **Describe** how text can be transformed into structured triples (subject – predicate – object).
3. **Run a Julia script** that sends prompts to an LLM and parses the structured response.
4. **Build and visualise** a small knowledge graph from LLM-extracted triples.
5. **Identify limitations** of LLM-based extraction (hallucinations, omissions, bias) and strategies to mitigate them.

## Audience & Prerequisites

| | |
|---|---|
| **Who** | Researchers, practitioners, and students from any discipline — no specific background assumed. |
| **Programming** | None required. We live-code together; you follow along. |
| **Software** | [Julia ≥ 1.9](https://julialang.org/downloads/), [VS Code](https://code.visualstudio.com/) with the [Julia extension](https://www.julia-vscode.org/), and **one** LLM backend: a local runtime such as [GPT4All](https://gpt4all.io/), [Ollama](https://ollama.com/), or [LM Studio](https://lmstudio.ai/) — **or** a free account at [OpenRouter](https://openrouter.ai/) (API key). See [Setup](#setup) for details. |
| **Bring a text** | A short text (1–3 paragraphs, roughly 100–500 words) from your own domain that you would like to turn into a knowledge graph. Good candidates are abstracts, executive summaries, or short encyclopedia entries — long enough to contain several entities and relationships, but short enough for the LLM to process in one go. |


We follow Carpentries pedagogy:

- Short explanations followed by **hands-on exercises** (live-coding, pair work).
- A pace that leaves room for questions.
- Emphasis on **conceptual understanding** over mathematical detail.

## Setup

Please complete the following steps **before** the workshop so we can dive straight into coding.

### 1. Install Julia

Download and install **Julia ≥ 1.9** from <https://julialang.org/downloads/>.
After installation, open a terminal and verify it works:

```
julia --version
```

### 2. Install VS Code + Julia extension

1. Download and install [Visual Studio Code](https://code.visualstudio.com/).
2. Open VS Code, go to the **Extensions** panel (`Ctrl+Shift+X` / `Cmd+Shift+X`), search for **Julia**, and install the [Julia extension](https://www.julia-vscode.org/).

### 3. Set up an LLM backend

You need **one** of the following so the workshop scripts can talk to a Large Language Model:

| Option | Install | Notes |
|---|---|---|
| [GPT4All](https://gpt4all.io/) | Download the desktop app, then download a model (e.g. *Mistral Instruct*). Enable the **local API server** (port 4891) in Settings → Server. | Free, runs offline. |
| [Ollama](https://ollama.com/) | Install the CLI, then run `ollama pull mistral`. | Free, runs offline. |
| [LM Studio](https://lmstudio.ai/) | Download the app, download a model, start the local server. | Free, runs offline. |
| [OpenRouter](https://openrouter.ai/) | Create a free account and generate an API key at <https://openrouter.ai/keys>. | Runs in the cloud; requires an internet connection and a (free) API key. |

Pick whichever option you are most comfortable with. If in doubt, **GPT4All** is the easiest to get started with.

### 4. Download the workshop materials

[**Download ZIP**](https://github.com/RailEduKit/spring-school-2026-knowledge-graphs/archive/refs/heads/main.zip) — or clone with Git:

```
git clone https://github.com/RailEduKit/spring-school-2026-knowledge-graphs.git
```

The `workshop/` folder contains:

```
workshop/
├── Utils.jl          # Helpers: read_text, save_yaml, read_pdf (optional)
├── Prompting.jl      # Module: talk to local or remote LLMs (prompt, set_backend!)
├── TextMining.jl     # Entity & relationship extraction (extract_entities, extract_relationships)
├── KnowledgeGraphs.jl # Build and visualise the graph (build_knowledge_graph, plot_knowledge_graph, save_knowledge_graph_png)
├── workshop.jl       # Entry point: Part A (provided example), Part B (your own data)
└── README.md         # ← you are here
```

### 5. Install Julia packages

Open the `workshop/` folder in VS Code, then open `workshop.jl` and run the first code block (Step 0). It activates the project environment and downloads all required Julia packages automatically. This may take a few minutes the first time.

## Schedule (90 min)

| Time | Section | Format |
|---:|---|---|
| 0 – 10 | **Welcome & Motivation** | Discussion |
| | Introductions. Why knowledge graphs? Real-world examples from research and industry. | |
| 10 – 25 | **Concepts: Text → Triples → Graph** | Lecture + Q&A |
| | Entities, relations, triples. What an LLM can (and cannot) do for information extraction. | |
| 25 – 45 | **Hands-on 1: Prompting an LLM from Julia** | Live-coding |
| | **Step 0–1:** Load `workshop.jl` (Utils, Prompting, TextMining, KnowledgeGraphs). Configure backend (`set_backend!` for local or OpenRouter), run a quick `prompt(...)` test. _Exercise:_ tweak the prompt to change what the model extracts. | |
| 45 – 70 | **Hands-on 2: From Triples to a Knowledge Graph** | Live-coding |
| | **Part A:** Run the provided railway example in `workshop.jl`: `extract_entities`, `extract_relationships`, `build_knowledge_graph`, `plot_knowledge_graph`. **Part B:** Use your own text (e.g. `read_text`) and repeat the pipeline. Explore: _Which node has the most connections? Can you spot thematic clusters?_ | |
| 70 – 85 | **Reflection: Quality, Limits, Ethics** | Group discussion |
| | How reliable are the extracted edges? Hallucinations, omissions, bias. Strategies: better prompts, human-in-the-loop, hybrid pipelines. | |
| 85 – 90 | **Wrap-up & Next Steps** | Plenary |
| | Key take-aways. Pointers to further resources. Feedback (short survey). | |

## Key Points

- A **knowledge graph** represents information as a network of entities (nodes) connected by typed relationships (edges).
- **LLMs** can extract candidate triples from unstructured text, but their output must be validated — they hallucinate, omit, and reflect training-data biases.
- **Julia** offers a fast, expressive environment for scripting the full pipeline: prompt an LLM → parse JSON → build & visualise a graph.
- Good **prompt design** is the most accessible lever for improving extraction quality.

## Optional Preparation

- Bring **1–2 short texts** from your own domain (max 2 pages) — we may use them as an alternative corpus.
- Walk through the [Setup](#setup) steps before the workshop so everything is ready to go.

## Going Further

- Scale up with larger corpora and batch prompting.
- Store graphs in dedicated databases (Neo4j, RDF triple stores).
- Combine LLM extraction with classical NLP (Named Entity Recognition, dependency parsing).
- Explore Julia's graph ecosystem: [Graphs.jl](https://github.com/JuliaGraphs/Graphs.jl), [GraphPlot.jl](https://github.com/JuliaGraphs/GraphPlot.jl), [TextAnalysis.jl](https://juliatext.github.io/TextAnalysis.jl/latest/).

## References

- **The Carpentries** — teaching methodology: <https://carpentries.org/>
- Hogan, A. et al. (2021). *Knowledge Graphs*. Synthesis Lectures on Data, Semantics, and Knowledge. <https://doi.org/10.1145/3447772>
- **Julia language**: <https://julialang.org/>
- **OpenRouter API**: <https://openrouter.ai/docs>
