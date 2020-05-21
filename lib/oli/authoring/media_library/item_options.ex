defmodule Oli.Authoring.MediaLibrary.ItemOptions do

  defstruct [:offset, :limit, :mime_filter, :search_text, :order_field, :order]

  @type t() :: %__MODULE__{
    offset: integer,
    limit: integer,
    mime_filter: String.t,
    search_text: String.t,
    order_field: String.t,
    order: String.t
  }

  def default() do
    %__MODULE__{
     order_field: "file_name",
     order: "asc"
    }
  end

  def from_client_options(options) do
    %__MODULE__{
      offset: Map.get(options, "offset", nil),
      limit: Map.get(options, "limit", nil),
      mime_filter: Map.get(options, "mimeFilter", nil),
      search_text: Map.get(options, "searchText", nil),
      order_field:  Map.get(options, "orderBy", "file_name"),
      order: Map.get(options, "order", "asc"),
    }
  end

end
