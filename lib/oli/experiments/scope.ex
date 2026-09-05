defmodule Oli.Experiments.Scope do
  @moduledoc """
  Explicit caller and tenancy scope for experiment context operations.
  """

  defstruct [
    :author_id,
    :institution_id,
    :project_id,
    :project_slug,
    :publication_id,
    :section_id,
    :section_slug,
    :user_id,
    :enrollment_id,
    :project_relationship?
  ]

  @type t :: %__MODULE__{
          author_id: integer() | nil,
          institution_id: integer() | nil,
          project_id: integer() | nil,
          project_slug: String.t() | nil,
          publication_id: integer() | nil,
          section_id: integer() | nil,
          section_slug: String.t() | nil,
          user_id: integer() | nil,
          enrollment_id: integer() | nil,
          project_relationship?: boolean() | nil
        }
end
