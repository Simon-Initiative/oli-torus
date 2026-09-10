defmodule Oli.Experiments.EligibleExperimentSection do
  @moduledoc """
  Authoring-safe summary of a section eligible for experiment participation.
  """

  @enforce_keys [:id, :slug, :title, :status]
  defstruct [:id, :slug, :title, :status, :start_date, :end_date]

  @type t :: %__MODULE__{
          id: integer(),
          slug: String.t(),
          title: String.t(),
          status: atom(),
          start_date: DateTime.t() | nil,
          end_date: DateTime.t() | nil
        }
end
