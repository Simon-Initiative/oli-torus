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
    if Enum.any?(children, fn c ->
         !Map.has_key?(c, "type") or Map.get(c, "type") != "code_line"
       end) do
      children = Enum.map(children, &to_code_line/1)
      {["Adjusted code block contents"], Map.put(item, "children", children)}
    else
      {[], item}
    end
  end

  def scrub(%{"model" => model} = item) do
    {changes, model} = scrub(model)
    {changes, Map.put(item, "model", model)}
  end

  def scrub(%{"children" => children} = item) do
    {changes, children} = scrub(children)
    {changes, Map.put(item, "children", children)}
  end

  def scrub(item) do
    {[], item}
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
