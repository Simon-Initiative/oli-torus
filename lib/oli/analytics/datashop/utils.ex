defmodule Oli.Analytics.Datashop.Utils do
  alias Oli.Rendering.Context
  alias Oli.Rendering.Content

  # For internal use and testing only, not for production file creation.
  def write_file(xml, file_name) do
    file_name = file_name <> ".xml"
    path = Path.expand(__DIR__) <> "/"

    case File.write(path <> file_name, xml) do
      :ok -> {:ok, path <> file_name, file_name}
      {:error, posix} -> {:error, posix}
    end
  end

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
    |> Phoenix.HTML.raw()
    |> Phoenix.HTML.safe_to_string()
    # Remove trailing newlines
    |> String.trim()
    # Convert to cdata
    |> parse_content
  end

  def hint_text(part, hint_id) do
    try do
      part["hints"]
      |> Enum.find(&(&1["id"] == hint_id))
      |> Map.get("content")
      |> parse_content
    rescue
      _e -> "Unknown hint text"
    end
  end

  def total_hints_available(part) do
    try do
      part
      |> Map.get("hints")
      |> length
    rescue
      _e -> "Unknown"
    end
  end

  # Datashop "contexts" are defined by a "session" of {user, problem, time} tuples
  # We don't make use of the timing information now, so it's omitted.
  def make_unique_id(activity_slug, part_id) do
    "#{activity_slug}-part#{part_id}-#{uuid()}"
  end

  def make_problem_name(activity_slug, part_id) do
    "Activity " <> activity_slug <> ", part " <> part_id
  end

  # For now, the dataset name is scoped to the project. Uploading datasets with the same name will
  # cause the data to be appended, so a guid is added to ensure a unique dataset is uploaded every time.
  # This will need to change if dataset processing is changed from "batch" to "live" updates.
  def make_dataset_name(project_slug) do
    "#{project_slug}-#{uuid()}"
  end
end
