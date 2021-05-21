defmodule Oli.Interop.Scrub do
  alias Oli.Resources.PageContent

  @doc """
  Content scrubbing routine to clean and adjust content found in ingested
  pages and activities. Takes a input the content to scrub and returns
  a tuple `{changes, scrubbed_content}` where `changes` is a list summarizing
  all changes made and `scrubbed_content` is the mutated content.
  """
  def scrub(items) when is_list(items) do
    {changes, items} =
      Enum.map(items, fn i -> scrub(i) end)
      |> Enum.unzip()

    {List.flatten(changes), items}
  end

  # Ensure that code blocks only contain `code_line` as children.  If they contain
  # anything else, extract all text from that child and convert the child to
  # a code_line
  def scrub(%{"type" => "code", "children" => children} = item) do
    item = ensure_id_present(item)

    if Enum.any?(children, fn c ->
         !Map.has_key?(c, "type") or Map.get(c, "type") != "code_line"
       end) do
      children = Enum.map(children, &to_code_line/1)
      {["Adjusted code block contents"], Map.put(item, "children", children)}
    else
      {[], item}
    end
  end

  def scrub(%{"model" => model} = item) when is_list(model) do
    {changes, model} = scrub(model)
    {changes, Map.put(item, "model", model)}
  end

  def scrub(%{"children" => children} = item) do
    item = ensure_id_present(item)

    {changes, children} = scrub(children)
    {changes, Map.put(item, "children", children)}
  end

  def scrub(item) do
    # To get to this impl of scrub, the item here is not a list, does not have
    # a "children" attribute, does not have "model" attribute that is a list,
    # and isn't a code block (or any other handed case). We will scrub this
    # item by scrubbing well known keys, allowing us to handle current and future
    # activity schemas
    Map.keys(item)
    |> Enum.reduce({[], ensure_id_present(item)}, fn key, {all, item} ->
      {changes, updated} = scrub_well_known(item, key)
      {changes ++ all, updated}
    end)
  end

  def scrub_well_known(item, "content"), do: scrub_well_known_key(item, "content")
  def scrub_well_known(item, "model"), do: scrub_well_known_key(item, "model")
  def scrub_well_known(item, "stem"), do: scrub_well_known_key(item, "stem")
  def scrub_well_known(item, "choices"), do: scrub_well_known_key(item, "choices")
  def scrub_well_known(item, "parts"), do: scrub_well_known_key(item, "parts")
  def scrub_well_known(item, "hints"), do: scrub_well_known_key(item, "hints")
  def scrub_well_known(item, "responses"), do: scrub_well_known_key(item, "responses")
  def scrub_well_known(item, "feedback"), do: scrub_well_known_key(item, "feedback")
  def scrub_well_known(item, "authoring"), do: scrub_well_known_key(item, "authoring")
  def scrub_well_known(item, _), do: {[], item}

  defp scrub_well_known_key(item, key) do
    {changes, scrubbed} =
      Map.get(item, key)
      |> scrub()

    {changes, Map.put(item, key, scrubbed)}
  end

  defp ensure_id_present(item) do
    case Map.get(item, "id") do
      nil -> Map.put(item, "id", Oli.Utils.random_string(12))
      _ -> item
    end
  end

  defp to_code_line(%{"type" => "code_line"} = item), do: item

  defp to_code_line(item) do
    %{
      "type" => "code_line",
      "children" => [
        %{
          "type" => "text",
          "text" => extract_text(item)
        }
      ]
    }
  end

  # From an arbitrary content element, recursively extract all "text" nodes, concatenating
  # them together to form a singular string
  defp extract_text(item) do
    PageContent.map_reduce(item, "", fn e, text -> {e, text <> Map.get(e, "text", "")} end)
    |> Tuple.to_list()
    |> Enum.at(1)
  end
end
