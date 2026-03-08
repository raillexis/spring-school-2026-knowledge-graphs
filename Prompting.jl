module Prompting

using HTTP
using JSON

export prompt, set_backend!

# ---- Helpers ----
function get_api_key(env_keys::Tuple, override::Union{AbstractString,Nothing})
    (override !== nothing && !isempty(override)) && return override
    for k in env_keys
        v = get(ENV, k, "")
        !isempty(v) && return v
    end
    return ""
end

function post_json(url, body; headers = ["Content-Type" => "application/json"])
    response = HTTP.post(url, headers, JSON.json(body))
    JSON.parse(String(response.body))
end

# ---- Backend implementations ----
function _ask_local(prompt; model, api_key, temperature, max_tokens, base_url = "http://localhost:4891", path = "/v1/chat/completions")
    url = rstrip(base_url, '/') * path
    body = Dict(
        "model" => model,
        "messages" => [Dict("role" => "user", "content" => prompt)],
        "temperature" => temperature,
        "max_tokens" => max_tokens,
    )
    data = post_json(url, body)
    data["choices"][1]["message"]["content"]
end

function _ask_openrouter(prompt; model, api_key, temperature, max_tokens, kwargs...)
    key = get_api_key(("OPENROUTER_API_KEY",), api_key)
    isempty(key) && error("OpenRouter API key required: set OPENROUTER_API_KEY")
    body = Dict(
        "model" => model,
        "messages" => [Dict("role" => "user", "content" => prompt)],
        "temperature" => temperature,
        "max_tokens" => max_tokens,
    )
    headers = ["Content-Type" => "application/json", "Authorization" => "Bearer $key"]
    data = post_json("https://openrouter.ai/api/v1/chat/completions", body; headers)
    if haskey(data, "error")
        err = data["error"]
        msg = haskey(err, "message") ? err["message"] : string(err)
        throw(ErrorException("OpenRouter API error: $msg"))
    end
    data["choices"][1]["message"]["content"]
end

const BACKENDS = Dict(
    :local => (default_model = "Llama 3 8B Instruct", fn = _ask_local),
    :openrouter => (default_model = "openrouter/auto", fn = _ask_openrouter),
)

# ---- Config (set via set_backend!) ----
mutable struct PromptConfig
    backend::Symbol
    model::String
    api_key::Union{String,Nothing}
    temperature::Float64
    max_tokens::Int
    base_url::String
    path::String
end

const CONFIG = Ref(PromptConfig(
    :local, # model backend
    "Llama 3 8B Instruct", # model name
    nothing, # api key
    0.3, # temperature - i.e. remove randomness from the output
    4096, # max tokens - i.e. the maximum number of tokens in the output
    "http://localhost:4891", # base url
    "/v1/chat/completions", # path
))

"""
    set_backend!(backend::Symbol; model=nothing, api_key=nothing, temperature=nothing, max_tokens=nothing, base_url=nothing, path=nothing)

Set backend and optional parameters for all subsequent `prompt(...)` calls.
- `backend`: `:local` (LM Studio, Ollama, gpt4all etc.) or `:openrouter`
- `model`: model name (defaults per backend if not set)
- `api_key`: API key (for OpenRouter; or set env OPENROUTER_API_KEY)
- `temperature`, `max_tokens`: sampling parameters
- `base_url`, `path`: for `:local` only (e.g. "http://localhost:4891", "/v1/chat/completions")

Omitted keyword arguments keep their current value (or backend default when switching backend).
"""
function set_backend!(backend::Symbol; model = nothing, api_key = nothing, temperature = nothing, max_tokens = nothing, base_url = nothing, path = nothing)
    haskey(BACKENDS, backend) || throw(ArgumentError("backend must be one of $(keys(BACKENDS)), got $backend"))
    c = CONFIG[]
    cfg = BACKENDS[backend]
    CONFIG[] = PromptConfig(
        backend,
        model !== nothing ? model : (c.backend == backend ? c.model : cfg.default_model),
        api_key !== nothing ? api_key : c.api_key,
        temperature !== nothing ? Float64(temperature) : c.temperature,
        max_tokens !== nothing ? Int(max_tokens) : c.max_tokens,
        base_url !== nothing ? base_url : c.base_url,
        path !== nothing ? path : c.path,
    )
end

"""
    prompt(input::AbstractString) -> AbstractString

Call the chat model using the current backend and options (see `set_backend!`).
Used by TextMining.jl for entity and relationship extraction.
"""
function prompt(input::AbstractString)

    c = CONFIG[]
    cfg = BACKENDS[c.backend]

    @debug "using backend: $(c.backend)"
    @debug "using model: $(c.model)"
    @debug "using temperature: $(c.temperature)"
    @debug "using max_tokens: $(c.max_tokens)"
    
    cfg.fn(input;
        model = c.model,
        api_key = c.api_key,
        temperature = c.temperature,
        max_tokens = c.max_tokens,
        base_url = c.base_url,
        path = c.path,
    )
end

end # module Prompting
