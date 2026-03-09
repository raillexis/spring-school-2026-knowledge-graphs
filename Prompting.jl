module Prompting

using HTTP
using JSON

export prompt, set_backend!, LAST_RESPONSE_INFO, LAST_FINISH_REASON

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
    local response
    try
        response = HTTP.post(url, headers, JSON.json(body))
    catch e
        if e isa HTTP.Exceptions.StatusError && e.status == 500
            msg = try String(e.response.body) catch; "" end
            if contains(msg, "too long")
                throw(ErrorException(
                    "Prompt too long for the model's context window. " *
                    "Increase the Context Length in your GPT4All / LLM server settings, " *
                    "or shorten the input. (Server returned: $(msg))"))
            end
            throw(ErrorException(
                "LLM server returned HTTP 500. This often means the prompt exceeds " *
                "the model's context length. Check your server settings. " *
                "(Server body: $(msg))"))
        end
        rethrow()
    end
    JSON.parse(String(response.body))
end

const LAST_RESPONSE_INFO = Ref("")
const LAST_FINISH_REASON = Ref("")

function _extract_finish_reason(data::AbstractDict)
    choices = get(data, "choices", nothing)
    (choices === nothing || isempty(choices)) && return "unknown"
    string(get(first(choices), "finish_reason", "unknown"))
end

function _log_response_info(data::AbstractDict)
    backend = CONFIG[].backend
    model   = get(data, "model", "unknown")
    status  = get(data, "object", "unknown")
    finish  = _extract_finish_reason(data)
    LAST_FINISH_REASON[] = finish
    usage   = get(data, "usage", nothing)
    if usage !== nothing
        prompt_tok     = get(usage, "prompt_tokens", "-")
        completion_tok = get(usage, "completion_tokens", "-")
        total_tok      = get(usage, "total_tokens", "-")
        @info "LLM response" backend model status finish_reason=finish prompt_tokens=prompt_tok completion_tokens=completion_tok total_tokens=total_tok
        LAST_RESPONSE_INFO[] = "backend=$backend  model=$model  status=$status  finish_reason=$finish  prompt_tokens=$prompt_tok  completion_tokens=$completion_tok  total_tokens=$total_tok"
    else
        @info "LLM response" backend model status finish_reason=finish usage="not reported"
        LAST_RESPONSE_INFO[] = "backend=$backend  model=$model  status=$status  finish_reason=$finish  usage=not reported"
    end
    if finish == "length"
        @warn "Response was TRUNCATED (finish_reason=length). Output may be incomplete — attempting JSON repair."
    end
end

# ---- Backend implementations ----
function _build_chat_body(; model, temperature, max_output_tokens, prompt_text)
    Dict(
        "model" => model,
        "messages" => [Dict("role" => "user", "content" => prompt_text)],
        "temperature" => temperature,
        "max_tokens" => max_output_tokens,
    )
end

function _ask_local(prompt; model, api_key, temperature, max_output_tokens, base_url = "http://localhost:4891", path = "/v1/chat/completions")
    url = rstrip(base_url, '/') * path
    body = _build_chat_body(; model, temperature, max_output_tokens, prompt_text = prompt)
    data = post_json(url, body)
    _log_response_info(data)
    data["choices"][1]["message"]["content"]
end

function _ask_openrouter(prompt; model, api_key, temperature, max_output_tokens, kwargs...)
    key = get_api_key(("OPENROUTER_API_KEY",), api_key)
    isempty(key) && error("OpenRouter API key required: set OPENROUTER_API_KEY")
    body = _build_chat_body(; model, temperature, max_output_tokens, prompt_text = prompt)
    headers = ["Content-Type" => "application/json", "Authorization" => "Bearer $key"]
    data = post_json("https://openrouter.ai/api/v1/chat/completions", body; headers)
    if haskey(data, "error")
        err = data["error"]
        msg = haskey(err, "message") ? err["message"] : string(err)
        throw(ErrorException("OpenRouter API error: $msg"))
    end
    _log_response_info(data)
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
    max_output_tokens::Int
    base_url::String
    path::String
end

const CONFIG = Ref(PromptConfig(
    :local, # model backend
    "Llama 3 8B Instruct", # model name
    nothing, # api key
    0.3, # temperature - i.e. remove randomness from the output
    16384, # generous default to avoid truncation
    "http://localhost:4891", # base url
    "/v1/chat/completions", # path
))

"""
    set_backend!(backend::Symbol; model=nothing, api_key=nothing, temperature=nothing, max_output_tokens=nothing, base_url=nothing, path=nothing)

Set backend and optional parameters for all subsequent `prompt(...)` calls.
- `backend`: `:local` (LM Studio, Ollama, gpt4all etc.) or `:openrouter`
- `model`: model name (defaults per backend if not set)
- `api_key`: API key (for OpenRouter; or set env OPENROUTER_API_KEY)
- `temperature`, `max_output_tokens`: sampling parameters (default: 16384)
- `base_url`, `path`: for `:local` only (e.g. "http://localhost:4891", "/v1/chat/completions")

Omitted keyword arguments keep their current value (or backend default when switching backend).
"""
function set_backend!(backend::Symbol; model = nothing, api_key = nothing, temperature = nothing, max_output_tokens = nothing, base_url = nothing, path = nothing)
    haskey(BACKENDS, backend) || throw(ArgumentError("backend must be one of $(keys(BACKENDS)), got $backend"))
    c = CONFIG[]
    cfg = BACKENDS[backend]
    CONFIG[] = PromptConfig(
        backend,
        model !== nothing ? model : (c.backend == backend ? c.model : cfg.default_model),
        api_key !== nothing ? api_key : c.api_key,
        temperature !== nothing ? Float64(temperature) : c.temperature,
        max_output_tokens !== nothing ? Int(max_output_tokens) : c.max_output_tokens,
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
    @debug "using max_output_tokens: $(c.max_output_tokens)"
    
    cfg.fn(input;
        model = c.model,
        api_key = c.api_key,
        temperature = c.temperature,
        max_output_tokens = c.max_output_tokens,
        base_url = c.base_url,
        path = c.path,
    )
end

end # module Prompting
