defmodule Oli.Publishing.PartMappingRefreshAdapter do
  alias Oli.Publishing.Publication

  @moduledoc """
    Behaviour for spawning a function that freshes the part_mapping materialized view:
  """

  @doc """
  Defines a callback to be used by refresh adapters
  """
  @callback maybe_refresh_part_mapping({:ok, %Publication{}} | {:error, %Ecto.Changeset{}}) ::
              {:ok, %Publication{}} | {:error, %Ecto.Changeset{}}
end
