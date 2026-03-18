module KnowledgeGraphs

using Graphs, MetaGraphs, GraphIO
using GraphMakie, GraphMakie.NetworkLayout, CairoMakie
using JSON, JSONSchema, YAML

export build_knowledge_graph, plot_knowledge_graph, save_knowledge_graph_png, save_knowledge_graph_gml, validate_graph

# -----------------------------------------------------------------------------
# Schema constants and validation
# -----------------------------------------------------------------------------

const SCHEMAS_DIR = joinpath(@__DIR__, "schemas")

# Unified knowledge-graph JSON Schema (draft-07): vertices = entities, edges = relationships
const SCHEMA = JSONSchema.Schema(read(joinpath(SCHEMAS_DIR, "knowledge-graph.json"), String))

# Sample payloads for prompts; sub-examples exposed for the two-phase extraction in TextMining
const _KG_EXAMPLE = YAML.load(read(joinpath(SCHEMAS_DIR, "knowledge-graph_example.yaml"), String))
const ENTITY_JSON_EXAMPLE = JSON.json(Dict("entities" => _KG_EXAMPLE["entities"]))
const RELATIONSHIP_JSON_EXAMPLE = JSON.json(Dict("relationships" => _KG_EXAMPLE["relationships"]))

"""Return true if `data` (Dict) conforms to the entity (vertex) part of the graph schema."""
validate_entities(data) = haskey(data, "entities") && JSONSchema.validate(SCHEMA, data) === nothing

"""Return true if `data` (Dict) conforms to the relationship (edge) part of the graph schema."""
validate_relationships(data) = haskey(data, "relationships") && JSONSchema.validate(SCHEMA, data) === nothing

"""Return true if `data` (Dict) conforms to the full graph schema (both entities and relationships)."""
validate_graph(data) = haskey(data, "entities") && haskey(data, "relationships") && JSONSchema.validate(SCHEMA, data) === nothing

# -----------------------------------------------------------------------------
# Plot defaults
# -----------------------------------------------------------------------------

const DEFAULT_TITLE = "Knowledge graph"
const DEFAULT_SIZE = (2000, 1400)
const DEFAULT_LAYOUT = Align(SFDP(; C = 5.0, K = 4.0, iterations = 700, tol = 0.01, seed = 42))
const NLABELS_DISTANCE = 6
const ELABELS_DISTANCE = 15
const DEFAULT_NODE_SIZE = 6
const DEFAULT_NODE_COLOR = :steelblue3
const DEFAULT_EDGE_WIDTH = 1.5
const DEFAULT_EDGE_COLOR = RGBAf(0.15, 0.15, 0.15, 0.45)
const DEFAULT_ARROW_SIZE = 12
const DEFAULT_CURVE_DISTANCE = 0.08
const DEFAULT_NODE_LABEL_SIZE = 10
const DEFAULT_EDGE_LABEL_SIZE = 9

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
            types = e["type"]
            set_prop!(g, i, :type, types isa AbstractVector ? join(types, ", ") : types)
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

function _make_figure(
    g;
    title = DEFAULT_TITLE,
    size = DEFAULT_SIZE,
    layout = DEFAULT_LAYOUT,
    show_edge_labels = false,
)
    nlabels = _vertex_labels(g)
    fig = Figure(; size)
    ax = Axis(fig[1, 1]; title)
    if show_edge_labels
        graphplot!(ax, g;
            nlabels,
            nlabels_align = (:center, :bottom),
            nlabels_distance = NLABELS_DISTANCE,
            nlabels_fontsize = DEFAULT_NODE_LABEL_SIZE,
            elabels = _edge_labels(g),
            elabels_distance = ELABELS_DISTANCE,
            elabels_fontsize = DEFAULT_EDGE_LABEL_SIZE,
            node_size = DEFAULT_NODE_SIZE,
            node_color = DEFAULT_NODE_COLOR,
            edge_width = DEFAULT_EDGE_WIDTH,
            edge_color = DEFAULT_EDGE_COLOR,
            arrow_size = DEFAULT_ARROW_SIZE,
            arrow_shift = :end,
            curve_distance = DEFAULT_CURVE_DISTANCE,
            curve_distance_usage = true,
            layout,
        )
    else
        graphplot!(ax, g;
            nlabels,
            nlabels_align = (:center, :bottom),
            nlabels_distance = NLABELS_DISTANCE,
            nlabels_fontsize = DEFAULT_NODE_LABEL_SIZE,
            node_size = DEFAULT_NODE_SIZE,
            node_color = DEFAULT_NODE_COLOR,
            edge_width = DEFAULT_EDGE_WIDTH,
            edge_color = DEFAULT_EDGE_COLOR,
            arrow_size = DEFAULT_ARROW_SIZE,
            arrow_shift = :end,
            curve_distance = DEFAULT_CURVE_DISTANCE,
            curve_distance_usage = true,
            layout,
        )
    end
    hidespines!(ax)
    hidedecorations!(ax)
    ax.aspect = DataAspect()
    return fig
end

# -----------------------------------------------------------------------------
# Public plot and save API
# -----------------------------------------------------------------------------

"""
    plot_knowledge_graph(g; title = "Knowledge graph", size = DEFAULT_SIZE, layout = DEFAULT_LAYOUT, show_edge_labels = false)

Plot the knowledge graph (MetaDiGraph) with Makie. Node labels are shown by default;
edge labels can be enabled with `show_edge_labels = true`.
Returns the Figure. Call `display(fig)` from the caller if needed.
"""
function plot_knowledge_graph(g; title = DEFAULT_TITLE, size = DEFAULT_SIZE, layout = DEFAULT_LAYOUT, show_edge_labels = false)
    fig = _make_figure(g; title, size, layout, show_edge_labels)
    display(fig)
    return fig
end

"""
    save_knowledge_graph_png(g, path; title = "Knowledge graph", size = DEFAULT_SIZE, layout = DEFAULT_LAYOUT, show_edge_labels = false)

Render the knowledge graph and save it as a PNG file. Returns the path.
"""
function save_knowledge_graph_png(g, path; title = DEFAULT_TITLE, size = DEFAULT_SIZE, layout = DEFAULT_LAYOUT, show_edge_labels = false)
    fig = _make_figure(g; title, size, layout, show_edge_labels)
    save(path, fig)
    return path
end

"""
    save_knowledge_graph_gml(g, path; gname = "knowledge_graph")

Save the knowledge graph (MetaDiGraph) as GML via GraphIO. Returns the path.
"""
function save_knowledge_graph_gml(g, path; gname = "knowledge_graph")
    savegraph(path, g, gname, GraphIO.GMLFormat())
end

end # module KnowledgeGraphs
