defmodule Oli.Authoring.MediaLibrary.ItemOptions do

  defstruct [:offset, :limit, :mime_filter, :url_filter, :search_text, :order_field, :order]

  @type t() :: %__MODULE__{
    offset: integer,
    limit: integer,
    mime_filter: [String.t],
    url_filter: String.t,
    search_text: String.t,
    order_field: String.t,
    order: String.t
  }

  def default() do
    %__MODULE__{
     offset: 0,
     limit: 60,
     mime_filter: nil,
     url_filter: nil,
     search_text: nil,
     order_field: "file_name",
     order: "asc"
    }
  end

  def from_client_options(options) do

    mime_filter = case Map.get(options, "mimeFilter", nil) do
      nil -> nil
      str -> String.split(str, ",")
    end

    %__MODULE__{
      offset: Map.get(options, "offset", "0") |> String.to_integer(),
      limit: Map.get(options, "limit", "60") |> String.to_integer(),
      mime_filter: mime_filter,
      url_filter: Map.get(options, "urlFilter", nil),
      search_text: Map.get(options, "searchText", nil),
      order_field:  Map.get(options, "orderBy", "file_name"),
      order: Map.get(options, "order", "asc"),
    }
  end

end
