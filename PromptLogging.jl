module PromptLogging

using Dates
using Main.Prompting: LAST_RESPONSE_INFO

export LOG_DIR, logging

const LOG_DIR = Ref(joinpath(@__DIR__, "log"))
const TIMESTAMP_FILE = "yyyymmdd_HHMMSS"
const TIMESTAMP_DISPLAY = "yyyy-mm-dd HH:MM:SS"

function _ensure_dir(dir)
    isdir(dir) || mkpath(dir)
end

function _timestamp()
    t = now()
    (file = Dates.format(t, TIMESTAMP_FILE),
     display = Dates.format(t, TIMESTAMP_DISPLAY))
end

function _section(io, title, content)
    println(io, "── $title ──")
    println(io, content)
    println(io)
end

"""
    logging(label, prompt_text, raw_response) -> String

Write the timestamp, LLM response info, prompt, and raw LLM response to a
file under `LOG_DIR[]`. Returns the file path.
"""
function logging(label::AbstractString, prompt_text::AbstractString, raw_response::AbstractString)
    _ensure_dir(LOG_DIR[])
    ts = _timestamp()
    m = match(r"backend=(\S+)", LAST_RESPONSE_INFO[])
    backend = m !== nothing ? replace(m.captures[1], r"[^A-Za-z0-9_\-\.]" => "_") : "unknown"
    path = joinpath(LOG_DIR[], "$(label)_$(backend)_$(ts.file).txt")
    open(path, "w") do io
        _section(io, ts.display, "")
        _section(io, "LLM response info", LAST_RESPONSE_INFO[])
        _section(io, "prompt", prompt_text)
        _section(io, "raw LLM response", raw_response)
    end
    @info "Saved LLM log" path
    path
end

end # module PromptLogging
