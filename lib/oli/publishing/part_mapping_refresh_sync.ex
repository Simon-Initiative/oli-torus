defmodule Oli.Publishing.PartMappingRefreshSync do
  alias Oli.Publishing.PartMappingRefreshAdapter

  @type ecto_publication_operation :: PartMappingRefreshAdapter.ecto_publication_operation()

  @behaviour PartMappingRefreshAdapter

  @doc """
    Mock implementation of the refresh adapter,
    the refresh operation is ran synchronously to simplify testing
  """
  @impl PartMappingRefreshAdapter
  @spec maybe_refresh_part_mapping(ecto_publication_operation) :: ecto_publication_operation
  def maybe_refresh_part_mapping({:ok, _publication} = operation_result) do
    Oli.Publishing.refresh_part_mapping()
    operation_result
  end

  def maybe_refresh_part_mapping(result), do: result
end
