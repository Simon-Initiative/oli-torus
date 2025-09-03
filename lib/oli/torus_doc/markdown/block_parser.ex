defmodule Oli.TorusDoc.Markdown.BlockParser do
  @moduledoc """
  Handles block-level parsing for TMD, including block math.
  """

  @doc """
  Preprocesses markdown to handle block-level math delimiters.
  Converts $$ ... $$ blocks to a format Earmark can preserve.
  """
  def preprocess_math(markdown) do
    # Pattern for block math: $$ on its own line
    block_math_regex = ~r/^\$\$\s*$(.+?)^\$\$\s*$/ms

    Regex.replace(block_math_regex, markdown, fn _, math_content ->
      # Convert to a code block with special language tag
      "```__torus_math__\n#{String.trim(math_content)}\n```"
    end)
  end

  @doc """
  Transforms a code block that might be math.
  """
  def transform_code_block("__torus_math__", content) do
    %{
      "type" => "formula",
      "subtype" => "latex",
      "src" => content
    }
  end

  def transform_code_block(language, content) do
    %{
      "type" => "code",
      "language" => language,
      "code" => content
    }
  end
end
