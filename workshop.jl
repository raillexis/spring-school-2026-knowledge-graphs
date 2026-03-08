# =============================================================================
# Knowledge Graph Workshop — Hands-On Tutorial
# =============================================================================
#
# A "knowledge graph" links concepts (entities) with labelled relationships.
# In this workshop you will build one automatically from plain text, using a
# Large Language Model (LLM) to do the heavy lifting.
#
# The script has three sections:
#   Section A: Steps 0–1 — Set up your environment and connect to an LLM.
#   Section B: Steps 2–6 — Run a PROVIDED example to see the full pipeline.
#   Section C: Your turn — Build a knowledge graph from YOUR OWN text.
#
# HOW TO USE THIS SCRIPT
#   • Work through the Steps in order, from top to bottom.
#   • Run each code block one at a time (select the lines, then press
#     Shift+Enter or use the "Run" button in your editor).
#   • Read the comments before each block — they explain what will happen.
#   • If anything is unclear, ask your facilitator!


# =============================================================================
# Section A: Steps 0–1 — Set up your environment and connect to an LLM.
# =============================================================================
# -----------------------------------------------------------------------------
# STEP 0: Load all required packages
# -----------------------------------------------------------------------------
# This step activates the project environment and downloads any missing
# packages.  You only need to run it once when you start a new Julia session.
# It may take a minute the very first time (packages are being installed).

using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

include("Utils.jl")
using .Utils: save_yaml, read_text, get_pdf_text, collect_entity_types
include("Prompting.jl")
using .Prompting: prompt, set_backend!
include("TextMining.jl")
using .TextMining: extract_entities, extract_relationships
include("KnowledgeGraphs.jl")
using .KnowledgeGraphs: build_knowledge_graph, plot_knowledge_graph, save_knowledge_graph_png

# -----------------------------------------------------------------------------
# STEP 1: Connect to the LLM (Large Language Model)
# -----------------------------------------------------------------------------
# The LLM analyses text for you.  It can run on your own machine ("local") or
# in the cloud via OpenRouter.  Pick ONE of the two Options below:
#   • To use an Option:  remove the leading "#" so the line becomes active code.
#   • To disable it:     put a "#" back at the start of the line.

# Option A — Local model (LM Studio, Ollama, GPT4All, etc. on port 4891):
set_backend!(:local, base_url = "http://localhost:4891", path = "/v1/chat/completions", max_tokens = 4096)

# Option B — Cloud model via OpenRouter (needs an API key):
# set_backend!(:openrouter, model = "openrouter/auto", api_key = "your-key-here")

# Quick test: run this line — if you see a short answer, your LLM is working.
println("Quick test — LLM response: ", prompt("Name two technical railway terms!"))

# =============================================================================
# Section B: Steps 2–6: Run the provided example (railway text)
# =============================================================================
# Walk through the full pipeline with a short sample text so you can see every
# Step in action before trying your own data.

# ---- Step 2: Start with some text --------------------------------------------
# This is the raw input.  The LLM will read it and pull out structured
# information (entities and relationships) that we can turn into a graph.

example_text = """
The rail has a crack. The train runs on the track. Track has two rails.
DB is responsible for maintaining the track.
"""
# or load from a file:
#example_text = read_text("examples/simple.txt")
#example_text = get_pdf_text("examples/simple.pdf")

# ---- Step 3: Extract entities -------------------------------------------------
# "Entities" are the key concepts in the text (things, people, organisations…).
# We tell the LLM which *types* of entities to look for.  You can customise
# these types to match your domain or leave them empty to let the LLM decide.

println("Default entity types: ", TextMining.ENTITY_TYPES)

entity_types = ["Infrastructure", "Vehicle", "Defect", "Standard", "Organisation"]
# or leave empty to let the LLM decide:
#entity_types = [""]

entities = extract_entities(example_text; types = entity_types)

println("Extracted ", length(entities), " entities.")

# Optionally save the result to a YAML file so you can inspect or reuse it:
#save_yaml(entities, "entities.yaml")
# Optionally show the entity types if you used an empty list:
#println("Entity types: ", collect_entity_types(entities))

# ---- Step 4: Extract relationships --------------------------------------------
# "Relationships" describe how entities are connected (e.g. a train OPERATES_ON
# a track).  Again, you can specify which relationship types to look for.

println("Default relationship types: ", TextMining.RELATIONSHIP_TYPES)

relationship_types = ["OPERATES_ON", "RESPONSIBLE_FOR", "PART_OF", "MANUFACTURED_BY", "RELATED_TO", "COMPOSED_OF"]
# or leave empty to let the LLM decide:
#relationship_types = [""]

relationships = extract_relationships(example_text, entities; types = relationship_types)

println("Extracted ", length(relationships), " relationships.")

# Optionally save the result to a YAML file so you can inspect or reuse it:
#save_yaml(relationships, "relationships.yaml")

# ---- Step 5: Build the knowledge graph ----------------------------------------
# Combine the entities (nodes) and relationships (edges) into a graph structure.

graph = build_knowledge_graph(entities, relationships)

# ---- Step 6: Visualise the graph ----------------------------------------------
# A window should open showing the knowledge graph.  Nodes are entities, and
# the arrows between them are the relationships the LLM found.

plot_knowledge_graph(graph)
# Optionally save the result to a PNG file so you can inspect or reuse it:
#save_knowledge_graph_png(graph, "knowledge_graph.png")


# =============================================================================
# Section C: Your turn — Build a knowledge graph from YOUR OWN text
# =============================================================================
# Now repeat the same Steps with text you care about.
#
# To get started:
#   1. Remove the "#" at the start of each line in the block below.
#   2. Replace "your_file.txt" with the path to your text file,
#      or delete that line and paste your text directly as a string.
#   3. Adjust the entity and relationship types to match your domain.
#   4. Run the block — a new graph window should appear.
#
# TROUBLESHOOTING
#   • No entities found?  Try broader types (e.g. add "Other") or check that
#     your LLM backend is still responding (re-run the quick test in Step 1).
#   • Graph looks messy?  Start with a shorter excerpt (2–3 paragraphs) and
#     refine entity/relationship types to reduce noise.
#   • Working with PDFs?  Use read_pdf("file.pdf") instead of read_text.
# -----------------------------------------------------------------------------

# my_text = read_text("your_file.txt")
# my_entity_types = ["Person", "Organization", "Concept", "Event", "Other"]
# my_entities = extract_entities(my_text; types = my_entity_types)
# my_relationships = extract_relationships(my_text, my_entities)
# my_graph = build_knowledge_graph(my_entities, my_relationships)
# plot_knowledge_graph(my_graph; title = "My knowledge graph")
# save_knowledge_graph_png(my_graph, "my_knowledge_graph.png")
