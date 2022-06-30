defmodule Oli.Publishing.PartMappingRefreshAsync do
  alias Oli.Publishing.PartMappingRefreshAdapter

  @type ecto_publication_operation :: PartMappingRefreshAdapter.ecto_publication_operation

  @behaviour PartMappingRefreshAdapter

  @impl PartMappingRefreshAdapter
  @spec maybe_refresh_part_mapping(ecto_publication_operation) :: ecto_publication_operation
  def maybe_refresh_part_mapping({:ok, _publication} = operation_result) do
    Task.start(fn ->
      Process.sleep(5_000)
      Oli.Publishing.refresh_part_mapping()
    end)
    operation_result
  end

  def maybe_refresh_part_mapping(result), do: result
end
