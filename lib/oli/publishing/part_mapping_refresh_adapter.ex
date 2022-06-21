defmodule Oli.Publishing.PartMappingRefreshAdapter do
  alias Oli.Publishing.Publication

  @moduledoc """
    Behaviour for spawning a function that freshes the part_mapping materialized view:
  """

  @type ecto_publication_operation :: {:ok, %Publication{}} | {:error, %Ecto.Changeset{}}

  @doc """
  Defines a callback to be used by refresh adapters
  """
  @callback maybe_refresh_part_mapping(ecto_publication_operation) :: ecto_publication_operation
end
