defmodule Oli.Publishing.PartMappingRefreshAsync do
  alias Oli.Publishing.PartMappingRefreshAdapter
  alias Oli.Publishing.PartMappingRefreshWorker

  @type ecto_publication_operation :: PartMappingRefreshAdapter.ecto_publication_operation()

  @behaviour PartMappingRefreshAdapter

  @impl PartMappingRefreshAdapter
  @spec maybe_refresh_part_mapping(ecto_publication_operation) :: ecto_publication_operation
  def maybe_refresh_part_mapping({:ok, _publication} = operation_result) do
    PartMappingRefreshWorker.create()
    operation_result
  end

  def maybe_refresh_part_mapping(result), do: result
end
