defmodule Oli.Rendering.Utils do
  alias Oli.Rendering.{Content, Context}

  def parse_html_content(content, context \\ %Context{}) do
    Content.render(context, content, Content.Html)
    |> Phoenix.HTML.raw()
    |> Phoenix.HTML.safe_to_string()
    # Remove trailing newlines
    |> String.trim()
  end

  # Code block language options
  # Pretty Name => HTML ClassName (for highlight JS highlighting)
  def code_languages() do
    %{
      "Assembly" => "x86asm",
      "C" => "c",
      "C#" => "csharp",
      "C++" => "cpp",
      "Elixir" => "elixir",
      "Golang" => "golang",
      "Haskell" => "haskell",
      "HTML" => "html",
      "Java" => "java",
      "JavaScript" => "javascript",
      "Kotlin" => "kotlin",
      "Lisp" => "lisp",
      "ML" => "ml",
      "Perl" => "perl",
      "PHP" => "php",
      "Python" => "python",
      "R" => "r",
      "Ruby" => "ruby",
      "SQL" => "sql",
      "Text" => "text",
      "TypeScript" => "typescript",
      "XML" => "xml",
    }
  end
end
