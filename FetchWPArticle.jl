"""
    FetchWPArticle

Module for downloading Wikipedia articles as PDF and stripping boilerplate
(table of contents, index, references, literature) from extracted PDF text.
"""
module FetchWPArticle

using HTTP

const DEFAULT_LANG = "en"

"""
    download_wikipedia_pdf(article_name, output_path; lang = "en") -> String

Download a Wikipedia article as PDF and save it to `output_path`.

- `article_name` - Article title (e.g. "Berlin", "Fahrstraße", "Albert_Einstein")
- `output_path` - Path where the PDF file will be saved
- `lang` - Wikipedia language code (default: "en" for English; use "de" for German, etc.)

Returns the path to the saved PDF file.

Uses Wikipedia's RESTBase API: `https://{lang}.wikipedia.org/api/rest_v1/page/pdf/{article}`

# Examples
```julia
download_wikipedia_pdf("Berlin", "berlin.pdf")
download_wikipedia_pdf("Fahrstraße", "fahrstrasse.pdf"; lang = "de")
```
"""
function download_wikipedia_pdf(article_name::AbstractString, output_path::AbstractString; lang::AbstractString = DEFAULT_LANG)
    # Wikipedia uses underscores for spaces in article names
    segment = replace(article_name, " " => "_")
    encoded = HTTP.escapeuri(segment)
    url = "https://$(lang).wikipedia.org/api/rest_v1/page/pdf/$(encoded)"
    response = HTTP.get(url)
    if HTTP.status(response) != 200
        error("Failed to download Wikipedia PDF: HTTP $(HTTP.status(response)) for article \"$article_name\"")
    end
    write(output_path, response.body)
    return output_path
end

"""
    strip_pdf_boilerplate(text; drop_toc = true, drop_trailing_sections = 5) -> String

Strip boilerplate sections from Wikipedia PDF-extracted text.

- `text` - Raw text extracted from a Wikipedia PDF (e.g. via `get_pdf_text`)
- `drop_toc` - If true (default), remove the first section (table of contents)
- `drop_trailing_sections` - Number of trailing sections to remove (default: 5).
  Typical Wikipedia PDFs end with: index, references, references caption, literature, literature caption.

Returns the cleaned text containing only the main article content.

# Examples
```julia
using .Utils: get_pdf_text
text = get_pdf_text("berlin.pdf")
clean = strip_wikipedia_boilerplate(text)
```
"""
function strip_wikipedia_boilerplate(text::AbstractString; drop_toc::Bool = true, drop_trailing_sections::Int = 5)
    result = text
    if drop_toc
        idx = findfirst("\n\n", result)
        if idx !== nothing
            result = result[last(idx) + 1:end]
        end
    end
    for _ in 1:drop_trailing_sections
        idx = findlast("\n\n", result)
        if idx === nothing
            break
        end
        result = result[1:first(idx) - 1]
    end
    result = String(strip(result)) # remove leading and trailing whitespace
    result = replace(result, r" {2,}" => " ") # replace 2+ spaces with one space
    return result
end

end # module FetchWPArticle
