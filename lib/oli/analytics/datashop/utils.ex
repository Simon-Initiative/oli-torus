defmodule Oli.Analytics.Datashop.Utils do
  alias Oli.Rendering.Context
  alias Oli.Rendering.Content

  # for making ids unique
  def uuid() do
    {:ok, uuid} = ShortUUID.encode(UUID.uuid4())
    uuid
  end

  # parse_content: make a cdata element from a parsed HTML string
  def parse_content(content) when is_binary(content) do
    {:cdata, content}
  end
  def parse_content(content) do
    Content.render(%Context{}, content, Content.Html)
    |> Phoenix.HTML.raw
    |> Phoenix.HTML.safe_to_string
    # Remove trailing newlines
    |> String.trim
    # Convert to cdata
    |> parse_content
  end

  def hint_text(part, hint_id) do
    try do
      part["hints"]
      |> Enum.find(& &1["id"] == hint_id)
      |> Map.get("content")
      |> parse_content
    rescue _e -> "Unknown hint text"
    end
  end

  def total_hints_available(part) do
    try do
      part
      |> Map.get("hints")
      |> length
    rescue _e -> "Unknown"
    end
  end

  # Datashop "contexts" are defined by a "session" of {user, problem, time} tuples
  # We don't make use of the timing information now, so it's omitted
  def make_context_message_id(email, activity_slug, part_id) do
    "#{email}-#{activity_slug}-part#{part_id}"
  end

  def make_transaction_id(context_message_id) do
    context_message_id <> "-" <> uuid()
  end

  def make_problem_name(activity_slug, part_id) do
    "Activity " <> activity_slug <> ", part " <> part_id
  end
end
