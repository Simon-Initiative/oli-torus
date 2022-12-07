defmodule Oli.Publishing.Publications.PublicationDiff do
  alias Oli.Publishing.Publications.Publication

  @enforce_keys [
    :classification,
    :edition,
    :major,
    :minor,
    :changes,
    :from_pub,
    :to_pub
  ]

  defstruct [
    :classification,
    :edition,
    :major,
    :minor,
    :changes,
    :from_pub,
    :to_pub
  ]

  @type t() :: %__MODULE__{
          classification: Atom.t(),
          edition: Integer.t(),
          major: Integer.t(),
          minor: Integer.t(),
          changes: Map.t(),
          from_pub: Publication.t(),
          to_pub: Publication.t()
        }
end
