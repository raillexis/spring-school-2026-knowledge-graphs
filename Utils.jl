module Utils

using JSON
using YAML
using PDFIO

function save_json(data, filename)
    open(filename, "w") do f
        JSON.print(f, data)
    end
end

function save_yaml(data, filename)
    YAML.write_file(filename, data)
end

function save_text(text, filename)
    open(filename, "w") do f
        write(f, text)
    end
end

function load_json(filename)
    JSON.parse(read(filename, String))
end

function load_yaml(filename)
    YAML.load(read(filename, String))
end

function load_text(filename)
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

"""
    collect_types(entities; type_key = "type") -> Vector{String}

Return a sorted vector of unique entity type labels found in `entities`
(a vector of dicts each containing a `type_key` key).
"""
function collect_types(entities; type_key = "type")
    sort!(collect(Set(e[type_key] for e in entities)))
end

end # module Utils