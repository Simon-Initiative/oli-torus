defmodule Oli.Rendering.Utils do
  alias Oli.Rendering.{Content, Context}

  def parse_html_content(content, context \\ %Context{}) do
    Content.render(context, content, Content.Html)
    |> Phoenix.HTML.raw()
    |> Phoenix.HTML.safe_to_string()
    # Remove trailing newlines
    |> String.trim()
  end
end
