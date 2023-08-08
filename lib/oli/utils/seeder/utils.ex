defmodule Oli.Utils.Seeder.Utils do
  import Oli.Utils

  alias Oli.Utils.Seeder.SeedRef

  @doc """
  Unpacks a list of possible refs and returns the unpacked values in
  the same order. If a ref is given that doesn't exist in the seeds map
  then an error will be thrown.

  This convenience function simplifies a batch resolution of maybe refs
  without having to declare each one using `maybe_ref` individually.

  Example:
    ```
    seeds = %{ project: %Project{}, ... }
    [%Author{}, %Project{}, nil] = unpack(seeds, [author, ref(:project), nil])
    ```

  Which is equivalent to:
    ```
    author = maybe_ref(author, seeds)
    project = maybe_ref(project, seeds)
    ...
    ```
  """
  def unpack(seeds, maybe_refs)

  def unpack(seeds, maybe_refs) do
    Enum.map(maybe_refs, fn r ->
      maybe_ref(r, seeds)
    end)
  end

  @spec ref(Atom.t()) :: SeedRef.t()
  def ref(tag), do: %SeedRef{tag: tag}

  def random_tag(), do: uuid()
  def random_tag(label) when is_atom(label), do: random_tag(to_string(label))
  def random_tag(label), do: "#{label}_#{uuid()}"

  # do not add values for which tags are nil
  def tag(seeds, nil, _value), do: seeds

  def tag(seeds, tag, value),
    do: Map.put(seeds, tag, value)

  def maybe_ref(%SeedRef{tag: tag}, seeds) do
    case(Map.get(seeds, tag)) do
      nil ->
        throw(
          "Failed to load #{to_string(tag)} from seeds. Please make sure the tag is correct and the value has previously been created."
        )

      value ->
        value
    end
  end

  def maybe_ref(value, _seeds), do: value
end
