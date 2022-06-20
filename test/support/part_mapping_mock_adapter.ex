defmodule Oli.PublishingTest.PartMappingMockAdapter do
  alias Oli.Publishing.Publication

  @behaviour Oli.Publishing.PartMappingRefreshAdapter

  @doc """
    Mock implementation of the refresh adapter,
    the refresh operation is ran synchronously to simplify testing
  """
  @impl Oli.Publishing.PartMappingRefreshAdapter
  @spec maybe_refresh_part_mapping({:ok, %Publication{}} | {:error, %Ecto.Changeset{}}) ::
          {:ok, %Publication{}} | {:error, %Ecto.Changeset{}}
  def maybe_refresh_part_mapping({:ok, _publication} = operation_result) do
    Oli.Publishing.refresh_part_mapping()
    operation_result
  end

  @impl Oli.Publishing.PartMappingRefreshAdapter
  def maybe_refresh_part_mapping(result), do: result
end
