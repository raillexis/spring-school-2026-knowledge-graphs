module KnowledgeGraphs

using Graphs, MetaGraphs, GraphIO
using GraphMakie, GraphMakie.NetworkLayout, CairoMakie
using JSON, JSONSchema, YAML

export build_knowledge_graph, plot_knowledge_graph, save_knowledge_graph_png, save_knowledge_graph_gml

# -----------------------------------------------------------------------------
# Schema constants and validation
# -----------------------------------------------------------------------------

const SCHEMAS_DIR = joinpath(@__DIR__, "schemas")

# JSON Schema definitions (draft-07) for entity and relationship extraction; loaded from workshop/schemas/
const ENTITY_JSON_SCHEMA = read(joinpath(SCHEMAS_DIR, "entity.json"), String)
const RELATIONSHIP_JSON_SCHEMA = read(joinpath(SCHEMAS_DIR, "relationship.json"), String)

# Sample payloads for prompts; loaded from YAML in workshop/schemas/ and exposed as JSON strings
const ENTITY_JSON_EXAMPLE = JSON.json(YAML.load(read(joinpath(SCHEMAS_DIR, "entity_example.yaml"), String)))
const RELATIONSHIP_JSON_EXAMPLE = JSON.json(YAML.load(read(joinpath(SCHEMAS_DIR, "relationship_example.yaml"), String)))

"""Return true if `data` (Dict) conforms to the entity extraction schema."""
validate_entities(data) = JSONSchema.validate(JSONSchema.Schema(ENTITY_JSON_SCHEMA), data) === nothing

"""Return true if `data` (Dict) conforms to the relationship extraction schema."""
validate_relationships(data) = JSONSchema.validate(JSONSchema.Schema(RELATIONSHIP_JSON_SCHEMA), data) === nothing

# -----------------------------------------------------------------------------
# Plot defaults
# -----------------------------------------------------------------------------

const DEFAULT_TITLE = "Knowledge graph"
const DEFAULT_SIZE = (800, 600)
const DEFAULT_LAYOUT = Spring(; seed = 42)
const NLABELS_DISTANCE = 10
const ELABELS_DISTANCE = 15

# -----------------------------------------------------------------------------
# Build graph (vertex props: name, type, id?; edge props: type, confidence, id?)
# -----------------------------------------------------------------------------

function _all_sorted_names(entities, relationships)
    names = unique(vcat(
        [e["name"] for e in entities],
        [r["source"] for r in relationships],
        [r["target"] for r in relationships],
    ))
    sort!(names)
    return names
end

function _set_vertex_props!(g, all_names, entity_by_name)
    for (i, name) in enumerate(all_names)
        set_prop!(g, i, :name, name)
        if haskey(entity_by_name, name)
            e = entity_by_name[name]
            set_prop!(g, i, :type, e["type"])
            haskey(e, "id") && set_prop!(g, i, :id, e["id"])
        else
            set_prop!(g, i, :type, "Other")
        end
    end
end

function _add_relationship_edges!(g, relationships, name_to_idx)
    for r in relationships
        s, t = r["source"], r["target"]
        haskey(name_to_idx, s) && haskey(name_to_idx, t) || continue
        si, ti = name_to_idx[s], name_to_idx[t]
        si == ti && continue
        add_edge!(g, si, ti) || continue
        set_prop!(g, si, ti, :type, r["type"])
        set_prop!(g, si, ti, :confidence, Float64(r["confidence"]))
        haskey(r, "id") && set_prop!(g, si, ti, :id, r["id"])
    end
end

"""
    build_knowledge_graph(entities, relationships) -> MetaDiGraph

Build a directed graph from extracted entities and relationships using MetaDiGraph.
Attaches all JSON Schema properties: on vertices (name, type, id), on edges (type, confidence, id).
Returns only the graph; labels for plotting are derived from vertex/edge properties.
"""
function build_knowledge_graph(entities, relationships)
    all_names = _all_sorted_names(entities, relationships)
    name_to_idx = Dict(name => i for (i, name) in enumerate(all_names))
    g = MetaDiGraph(length(all_names))
    entity_by_name = Dict(e["name"] => e for e in entities)
    _set_vertex_props!(g, all_names, entity_by_name)
    _add_relationship_edges!(g, relationships, name_to_idx)
    return g
end

# -----------------------------------------------------------------------------
# Plot helpers: labels and figure creation
# -----------------------------------------------------------------------------

function _vertex_labels(g)
    [string(get_prop(g, i, :name), " (", get_prop(g, i, :type), ")") for i in 1:Graphs.nv(g)]
end

function _edge_labels(g)
    [
        string(get_prop(g, Graphs.src(e), Graphs.dst(e), :type), " (", round(get_prop(g, Graphs.src(e), Graphs.dst(e), :confidence), digits = 2), ")")
        for e in Graphs.edges(g)
    ]
end

function _make_figure(g; title = DEFAULT_TITLE, size = DEFAULT_SIZE, layout = DEFAULT_LAYOUT)
    nlabels = _vertex_labels(g)
    elabels = _edge_labels(g)
    fig = Figure(; size)
    ax = Axis(fig[1, 1]; title)
    graphplot!(ax, g;
        nlabels,
        nlabels_align = (:center, :center),
        nlabels_distance = NLABELS_DISTANCE,
        elabels,
        elabels_distance = ELABELS_DISTANCE,
        layout,
    )
    hidespines!(ax)
    hidedecorations!(ax)
    ax.aspect = DataAspect()
    return fig
end

# -----------------------------------------------------------------------------
# Public plot and save API
# -----------------------------------------------------------------------------

"""
    plot_knowledge_graph(g; title = "Knowledge graph", size = (800, 600), layout = Spring(; seed = 42))

Plot the knowledge graph (MetaDiGraph) with Makie, showing vertex and edge meta properties.
Returns the Figure. Call `display(fig)` from the caller if needed.
"""
function plot_knowledge_graph(g; title = DEFAULT_TITLE, size = DEFAULT_SIZE, layout = DEFAULT_LAYOUT)
    fig = _make_figure(g; title, size, layout)
    display(fig)
end

"""
    save_knowledge_graph_png(g, path; title = "Knowledge graph", size = (800, 600), layout = Spring(; seed = 42))

Render the knowledge graph and save it as a PNG file. Returns the path.
"""
function save_knowledge_graph_png(g, path; title = DEFAULT_TITLE, size = DEFAULT_SIZE, layout = DEFAULT_LAYOUT)
    fig = _make_figure(g; title, size, layout)
    save(path, fig)
end

"""
    save_knowledge_graph_gml(g, path; gname = "knowledge_graph")

Save the knowledge graph (MetaDiGraph) as GML via GraphIO. Returns the path.
"""
function save_knowledge_graph_gml(g, path; gname = "knowledge_graph")
    savegraph(path, g, gname, GraphIO.GMLFormat())
end

end # module KnowledgeGraphs
