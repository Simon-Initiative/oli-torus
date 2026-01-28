defmodule Oli.Test.ClickhouseStub do
  @moduledoc false

  def raw_events_table, do: "analytics.raw_events"

  def query_status(_query_id), do: {:ok, %{status: :running}}

  def query_progress(_query_id), do: {:ok, :none}
end
