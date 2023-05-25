defmodule Oli.Analytics.DataTables.DataTable do

  alias CSV

  defstruct headers: [],
    rows: []

  @type t() :: %__MODULE__{
    headers: [key: :atom] ,
    rows: [any()],
  }

  def new(rows \\ []), do: %__MODULE__{rows: rows}

  def headers(%__MODULE__{} = table, headers) do
    %{table | headers: headers}
  end

  def rows(%__MODULE__{} = table, rows) do
    %{table | rows: rows}
  end

  def to_csv_content(%__MODULE__{headers: [], rows: rows}) do
    rows
    |> CSV.encode()
    |> Enum.join()
  end

  def to_csv_content(%__MODULE__{headers: headers, rows: rows}) do
    rows
    |> CSV.encode(headers: headers)
    |> Enum.join()
  end

end
