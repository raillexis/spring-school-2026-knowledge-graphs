module Utils

using JSON, JSONSchema
using YAML
using PDFIO

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

function save_json(data, filename)
    open(filename, "w") do f
        JSON.print(f, data)
    end
end

function save_yaml(data, filename)
    YAML.write_file(filename, data)
end

function read_json(filename)
    JSON.parse(read(filename, String))
end

function read_yaml(filename)
    YAML.load(read(filename, String))
end

function read_text(filename)
    read(filename, String)
end

"""
    get_pdf_text(src) -> String

- src - Input PDF file path from where text is to be extracted
- return - Extracted text from all pages (in memory, no file written)
"""
function get_pdf_text(src)
    doc = pdDocOpen(src)
    io = IOBuffer()
    npage = pdDocGetPageCount(doc)
    for i = 1:npage
        page = pdDocGetPage(doc, i)
        pdPageExtractText(io, page)
    end
    pdDocClose(doc)
    return String(take!(io))
end

end # module Utils