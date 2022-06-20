defmodule Oli.Publishing.PartMappingRefreshAsync do
  alias Oli.Publishing.Publication

  @behaviour Oli.Publishing.PartMappingRefreshAdapter

  @impl Oli.Publishing.PartMappingRefreshAdapter
  @spec maybe_refresh_part_mapping({:ok, %Publication{}} | {:error, %Ecto.Changeset{}}) ::
          {:ok, %Publication{}} | {:error, %Ecto.Changeset{}}
  def maybe_refresh_part_mapping({:ok, _publication} = operation_result) do
    Task.async(fn -> Oli.Publishing.refresh_part_mapping() end)
    operation_result
  end

  def maybe_refresh_part_mapping(result), do: result
end
