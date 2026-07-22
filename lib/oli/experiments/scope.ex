defmodule Oli.Experiments.Scope do
  @moduledoc """
  Explicit caller and tenancy scope for experiment context operations.
  """

  defstruct [
    :institution_id,
    :project_id,
    :project_slug,
    :publication_id,
    :section_id,
    :section_slug,
    :user_id,
    :enrollment_id
  ]

  @type t :: %__MODULE__{
          institution_id: integer() | nil,
          project_id: integer() | nil,
          project_slug: String.t() | nil,
          publication_id: integer() | nil,
          section_id: integer() | nil,
          section_slug: String.t() | nil,
          user_id: integer() | nil,
          enrollment_id: integer() | nil
        }
end
