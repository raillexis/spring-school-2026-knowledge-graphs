module TextMining

using JSON
# Use Prompting from Main if already loaded (e.g. by workshop.jl with chosen backend); otherwise load it
if isdefined(Main, :Prompting)
    using Main.Prompting: prompt
else
    include("Prompting.jl")
    using .Prompting: prompt
end
using Main.Utils: ENTITY_JSON_EXAMPLE, RELATIONSHIP_JSON_EXAMPLE, validate_entities, validate_relationships

# ---- Constants ----
const ENTITY_TYPES = [
    "Person", "Organization", "Location", "Date",
    "Event", "Product", "Technology", "Document",
    "Concept", "Quantity", "Other",
]
const ENTITY_RULES = [
    "Deduplicate: if the same real-world thing appears under different names or aliases, keep only the most specific canonical form.",
    "Prefer the official or most widely-recognised name (e.g. \"Deutsche Bahn\" not \"DB\", \"European Commission\" not \"the commission\").",
    "Use singular, title-cased names (e.g. \"Railway Bridge\" not \"railway bridges\").",
    "Skip pronouns, vague references (\"the system\", \"it\"), and overly generic terms unless they name a specific entity.",
    "Extract atomic entities — split compound mentions into separate nodes (e.g. \"Paris and Berlin\" → two Location entities).",
    "When the type is ambiguous, prefer the most specific applicable type.",
]
const RELATIONSHIP_TYPES = [
    # Spatial & hierarchy
    "LOCATED_IN", "PART_OF", "CONTAINS", "NEAR",
    # People & organisations
    "WORKS_FOR", "MEMBER_OF", "EMPLOYED_BY", "SUBSIDIARY_OF", "PARTNER_OF",
    # Roles & responsibility
    "RESPONSIBLE_FOR", "OPERATES_ON", "OPERATES_IN",
    # Creation & provenance
    "AUTHORED_BY", "MANUFACTURED_BY", "PUBLISHED_BY", "CREATED_BY",
    # Events & time
    "OCCURRED_AT", "OCCURRED_ON", "CAUSED_BY", "INVOLVES",
    # Documents & concepts
    "ABOUT", "CITES", "USES", "IMPLEMENTS", "SUCCEEDS",
    # Fallback
    "RELATED_TO",
]
const RELATIONSHIP_RULES = [
    "Each relationship must connect two entities from the provided entity list — use their exact canonical names.",
    "Prefer specific relationship types over generic ones.",
    "Only extract relationships that are explicitly stated or strongly implied by the text.",
    "Assign a confidence score between 0.0 and 1.0 reflecting how clearly the text supports the relationship.",
    "Do not invent relationships that require external knowledge beyond the text.",
    "Deduplicate: do not return the same (source, target, type) triple more than once.",]

# ---- Helpers ----
_format_rules(rules::Vector{String}) = join(("- " * r for r in rules), "\n")

function _deduplicate_by(v::Vector, key_fn)
    isempty(v) && return v
    seen = Set{typeof(key_fn(first(v)))}()
    filter(v) do x
        k = key_fn(x)
        k in seen ? false : (push!(seen, k); true)
    end
end

"""
    _parse_json_from_response(response_str) -> Union{Dict, Nothing}

Extract the first `{...}` JSON blob from `response_str` and parse it.
Returns `nothing` if no valid JSON block is found.
"""
function _parse_json_from_response(response_str::String)
    m = match(r"\{.*\}"s, response_str)
    m === nothing ? nothing : JSON.parse(m.match)
end

# ---- Public API ----
"""
    extract_entities(corpus; priming="", types=ENTITY_TYPES, rules=ENTITY_RULES, retries=2)

Extract named entities from `corpus` using an LLM. Returns a vector of entities
`(id, name, type)` or `nothing` if parsing failed after retries.
"""
function extract_entities(
    corpus::String;
    priming::String = "",
    types::Vector{String} = ENTITY_TYPES,
    rules::Vector{String} = ENTITY_RULES,
)
    types_str = join(types, ", ")
    rules_str = _format_rules(rules)

    instruction = """
        Extract all important entities from the text below.
        Each entity must have a short canonical name, and a type chosen from:
        $types_str.

        Rules:
        $rules_str

        Return ONLY valid JSON — no commentary, no markdown fences.
        Schema:
        $ENTITY_JSON_EXAMPLE

        Text:
        $corpus

        JSON:
        """

    full_prompt = isempty(priming) ? instruction : priming * "\n" * instruction

    @debug "Prompting model with: \n $full_prompt"

    raw_response = prompt(full_prompt)

    @debug "Model response: \n $raw_response"
    
    parsed = _parse_json_from_response(raw_response)

    @debug "Parsed JSON: \n $parsed"

    parsed === nothing && return nothing
    try
        if !validate_entities(parsed)
            @warn "Entity JSON did not validate against schema"
            return nothing
        end
        return collect(parsed["entities"])
    catch e
        @warn "Failed to parse entity JSON from model response" exception = e
        return nothing
    end
end

"""
    extract_relationships(corpus, entities; priming="", rules=RELATIONSHIP_RULES, min_confidence=0.0, retries=2)

Extract relationships between `entities` from `corpus` using an LLM. Returns a vector
of relationships `(source, target, type, confidence)` or `nothing` if parsing failed.
"""
function extract_relationships(
    corpus::String,
    entities::Vector;
    priming::String = "",
    types::Vector{String} = RELATIONSHIP_TYPES,
    rules::Vector{String} = RELATIONSHIP_RULES,
    min_confidence::Float64 = 0.0,
)
    entity_descriptions = join(("- $(e["name"]) ($(e["type"]))" for e in entities), "\n        ")
    rules_str = _format_rules(rules)
    relationship_types_str = join(RELATIONSHIP_TYPES, ", ")

    instruction = """
        Given the following entities extracted from a text, identify all meaningful relationships between them.
        Choose a concise, descriptive relationship type from the following list:
        $relationship_types_str.

        Entities:
        $entity_descriptions

        Rules:
        $rules_str

        Return ONLY valid JSON — no commentary, no markdown fences.
        Schema:
        $RELATIONSHIP_JSON_EXAMPLE

        Text:
        $corpus

        JSON:
        """

    full_prompt = isempty(priming) ? instruction : priming * "\n" * instruction
    
    @debug "Prompting model with: \n $full_prompt"

    raw_response = prompt(full_prompt)

    @debug "Model response: \n $raw_response"
    
    parsed = _parse_json_from_response(raw_response)

    @debug "Parsed JSON: \n $parsed"

    parsed === nothing && return nothing
    try
        if !validate_relationships(parsed)
            @warn "Relationship JSON did not validate against schema"
            return nothing
        end
        return collect(parsed["relationships"])
    catch e
        @warn "Failed to parse relationship JSON from model response" exception = e
        return nothing
    end
end

end # module TextMining
