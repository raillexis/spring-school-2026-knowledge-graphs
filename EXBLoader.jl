"""
    ExbLoader — Load EXMARaLDA Basic Transcription (.exb) files and extract text per speaker.

EXB is an XML-based format for time-aligned speech transcriptions. This module parses
EXB files and returns the transcription text grouped by speaker.
"""
module EXBLoader

using EzXML

export load_exb, text_by_speaker, SpeakerInfo

# ---- XML paths (EXB supports both speaker-table and speakertable) ----
const SPEAKER_TABLE_XPATH = "//speaker-table | //speakertable"
const TIER_XPATH = "//tier"
const TLI_XPATH = "//tli"
const EVENT_XPATH = "event | segment"

"""
    SpeakerInfo

Holds metadata for a speaker: `id` (e.g. "SPK0"), `abbreviation` (short label),
and optional `name` if present in the EXB.
"""
struct SpeakerInfo
    id::String
    abbreviation::String
    name::Union{String, Nothing}
end

const SpeakerEvent = @NamedTuple{speaker::String, t_start::Float64, t_end::Float64, content::String}

"""
    load_exb(path::AbstractString) -> (speakers::Dict{String, SpeakerInfo}, text_by_speaker::Dict{String, String})

Load an EXB file from `path` and return:
- `speakers`: mapping from speaker ID to `SpeakerInfo`
- `text_by_speaker`: mapping from speaker ID to the concatenated transcription text for that speaker

Text from multiple tiers belonging to the same speaker is concatenated in timeline order.
"""
function load_exb(path::AbstractString)
    doc = EzXML.readxml(path)
    root = EzXML.root(doc)
    _parse_exb(root)
end

"""
    text_by_speaker(path::AbstractString) -> Dict{String, String}

Convenience function: load EXB and return only the `text_by_speaker` mapping.
"""
function text_by_speaker(path::AbstractString)
    _, texts = load_exb(path)
    texts
end

"""
    text_by_speaker(path::AbstractString, use_abbreviation::Bool) -> Dict{String, String}

If `use_abbreviation=true`, use speaker abbreviation (e.g. "A", "B") as keys instead of ID ("SPK0", "SPK1").
"""
function text_by_speaker(path::AbstractString, use_abbreviation::Bool)
    speakers, texts = load_exb(path)
    use_abbreviation ? _remap_by_abbreviation(speakers, texts) : texts
end

function _remap_by_abbreviation(speakers::Dict{String, SpeakerInfo}, texts::Dict{String, String})
    result = Dict{String, String}()
    for (id, text) in texts
        abbr = get(speakers, id, SpeakerInfo(id, id, nothing)).abbreviation
        result[abbr] = haskey(result, abbr) ? result[abbr] * " " * text : text
    end
    result
end

# ---- Internal parsing ----

function _parse_exb(root::EzXML.Node)
    speakers = _parse_speakers(root)
    texts = _parse_text_by_speaker(root)
    (speakers, texts)
end

function _parse_speakers(root::EzXML.Node)
    speakers = Dict{String, SpeakerInfo}()
    for st in findall(SPEAKER_TABLE_XPATH, root)
        for node in findall("speaker", st)
            info = _parse_speaker(node)
            speakers[info.id] = info
        end
    end
    speakers
end

function _parse_speaker(node::EzXML.Node)
    id   = node["id"]
    abbr = _attr(node, "abbreviation")
    isempty(abbr) && (abbr = _child_text(node, "abbreviation"))
    SpeakerInfo(id, isempty(abbr) ? id : abbr, _speaker_name(node))
end

_attr(node::EzXML.Node, name::String, default::String="") =
    haskey(node, name) ? node[name] : default

_child_text(node::EzXML.Node, name::String) =
    (el = findfirst(name, node); el === nothing ? "" : strip(nodecontent(el)))

function _speaker_name(node::EzXML.Node)
    text = _child_text(node, ".//name")
    isempty(text) ? nothing : text
end


function _parse_text_by_speaker(root::EzXML.Node)
    tli_times = _build_timeline(root)
    events = _collect_events(root, tli_times)
    _group_by_speaker(events)
end

function _build_timeline(root::EzXML.Node)
    Dict(
        _attr(tli, "id") => something(tryparse(Float64, _attr(tli, "time", "0")), 0.0)
        for tli in findall(TLI_XPATH, root)
    )
end

function _tier_speaker_id(tier::EzXML.Node)
    id = _attr(tier, "speaker")
    isempty(id) ? _attr(tier, "speaker-id") : id
end

function _collect_events(root::EzXML.Node, tli_times::Dict{String, Float64})
    events = SpeakerEvent[]
    for tier in findall(TIER_XPATH, root)
        speaker = _tier_speaker_id(tier)
        isempty(speaker) && continue
        _collect_tier_events!(events, tier, speaker, tli_times)
    end
    sort!(events; by = ev -> (ev.t_start, ev.t_end))
end

function _collect_tier_events!(events, tier::EzXML.Node, speaker::String, tli_times::Dict{String, Float64})
    for ev in findall(EVENT_XPATH, tier)
        content = strip(nodecontent(ev))
        isempty(content) && continue

        start_ref = _attr(ev, "start")
        t_start = get(tli_times, start_ref, 0.0)
        t_end   = get(tli_times, _attr(ev, "end"), t_start)
        push!(events, SpeakerEvent((speaker, t_start, t_end, content)))
    end
end

function _group_by_speaker(events::Vector{SpeakerEvent})
    groups = Dict{String, Vector{String}}()
    for ev in events
        push!(get!(Vector{String}, groups, ev.speaker), ev.content)
    end
    Dict(spk => join(segs, " ") for (spk, segs) in groups)
end

end # module EXBLoader
