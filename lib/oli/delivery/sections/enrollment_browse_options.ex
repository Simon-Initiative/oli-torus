defmodule Oli.Delivery.Sections.EnrollmentBrowseOptions do
  @moduledoc """
  Params for enrollment browse queries.
  """

  @enforce_keys [
    :is_instructor,
    :is_student,
    :text_search
  ]

  defstruct [
    :is_instructor,
    :is_student,
    :text_search
  ]

  @type t() :: %__MODULE__{
          is_instructor: boolean(),
          is_student: boolean(),
          text_search: String.t()
        }
end
