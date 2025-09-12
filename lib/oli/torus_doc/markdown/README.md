# TorusDoc Markdown Parser

A comprehensive Markdown parser that converts TorusDoc Markdown (TMD) into Torus JSON content elements, following the TMD specification.

## Features

### Core Markdown Support
- **Headings**: H1-H6 (`# Heading`)
- **Paragraphs**: Standard paragraph blocks
- **Lists**: Ordered (`1.`) and unordered (`-`) with nesting support
- **Tables**: GitHub-flavored markdown tables with alignment
- **Code blocks**: Fenced code blocks with language highlighting
- **Blockquotes**: Quote blocks (`>`)
- **Inline formatting**: Bold (`**text**`), italic (`*text*`), code (`` `text` ``)
- **Links**: Standard markdown links (`[text](url)`)
- **Images**: Inline images (`![alt](src)`)

### Mathematical Content
- **Inline math**: LaTeX expressions using `\(expression\)` 
- **Block math**: Display math using fenced `$$` blocks

### Custom Directives

#### Block Directives
Custom block-level elements using the `:::name {attrs}` syntax:

```markdown
:::youtube { id="dQw4w9WgXcQ" start=42 title="Demo" }
:::

:::audio { src="/media/audio.mp3" caption="Audio caption" }
Optional transcript text here
:::

:::video { src="/media/video.mp4" poster="/thumb.jpg" }
Video description
:::

:::iframe { src="https://codepen.io/embed" width=640 height=360 }
:::
```

#### Inline Directives
Semantic inline elements using `:name[text]{attrs}` syntax:

```markdown
The :term[acceleration]{id="accel"} is defined as...
```

## Usage

```elixir
alias Oli.TorusDoc.MarkdownParser

# Parse markdown to Torus JSON
markdown = """
# Hello World

This is a **paragraph** with *formatting*.

- List item 1
- List item 2

\\(E = mc^2\\)
"""

{:ok, elements} = MarkdownParser.parse(markdown)
```

## Architecture

The parser is composed of several specialized modules:

- **`MarkdownParser`**: Main entry point and orchestrator
- **`DirectiveParser`**: Handles custom block directives (YouTube, audio, etc.)
- **`InlineParser`**: Processes inline elements and formatting
- **`BlockParser`**: Handles block-level math preprocessing
- **`TableParser`**: Specialized table parsing with GFM support

### Processing Pipeline

1. **Preprocessing**:
   - Inline math expressions are protected with placeholders
   - Inline directives are encoded
   - Block math is converted to special code blocks
   - Custom directives are extracted and replaced with placeholders

2. **Markdown Parsing**:
   - Uses Earmark with GFM extensions
   - Generates Abstract Syntax Tree (AST)

3. **Transformation**:
   - AST is transformed to Torus JSON schema
   - Placeholders are replaced with actual content
   - Validation is applied

## Validation

The parser includes built-in validation for security and content quality:

### YouTube Directives
- YouTube IDs must match the 11-character format: `/^[A-Za-z0-9_-]{11}$/`
- Invalid IDs result in error messages

### Media Sources
- Must be relative paths (`/path`, `./path`, `../path`) or use `https://` protocol
- Invalid sources are rejected with error messages

### Iframe Security
- Domain allowlist enforced for iframe sources
- Allowed domains include:
  - YouTube, Vimeo
  - CodePen, CodeSandbox, JSFiddle
  - Apple Music, Spotify embeds
- Disallowed domains result in security error messages

## Output Schema

The parser generates JSON conforming to the Torus content element schema (`content-element.schema.json`). Examples:

### Paragraph with Formatting
```json
{
  "type": "p",
  "children": [
    {"text": "Normal "},
    {"text": "bold", "strong": true},
    {"text": " and "},
    {"text": "italic", "em": true}
  ]
}
```

### List Structure
```json
{
  "type": "ul",
  "children": [
    {"type": "li", "children": [{"text": "Item 1"}]},
    {"type": "li", "children": [{"text": "Item 2"}]}
  ]
}
```

### Math Elements
```json
{
  "type": "formula_inline",
  "subtype": "latex",
  "src": "E=mc^2"
}
```

## Testing

The parser includes comprehensive test coverage:

```bash
# Run all parser tests
mix test test/oli/torus_doc/markdown_parser_test.exs

# Run specific test
mix test test/oli/torus_doc/markdown_parser_test.exs:LINE_NUMBER
```

Test categories:
- Basic text blocks (paragraphs, headings)
- Inline formatting (bold, italic, code, math)
- Lists (ordered, unordered, nested)
- Tables with alignment and formatting
- Code blocks with language specification
- Block and inline math
- Custom directives (YouTube, audio, video, iframe)
- Inline directives (term)
- Edge cases and error handling
- Validation scenarios

## Best Practices

1. **Always provide alt text** for images and media
2. **Use semantic directives** like `:term[]` for glossary terms
3. **Validate external content** - ensure YouTube IDs and URLs are correct
4. **Keep math simple** in inline contexts, use block math for complex equations
5. **Test directive output** - invalid directives show as error paragraphs

## Future Enhancements

Potential additions to the parser:
- Additional inline directives (citations, footnotes)
- More media directive types
- Extended table features (colspan, rowspan)
- Custom validation rules
- Markdown canonicalization for round-trip editing