defmodule Oli.Publishing.Publications.PublicationDiffKey do
  @enforce_keys [
    :key
  ]

  defstruct [
    :key
  ]

  @type t() :: %__MODULE__{
          key: String.t()
        }

  def key(from_pub_id, to_pub_id) do
    %__MODULE__{key: "#{from_pub_id}_#{to_pub_id}"}
  end
end
