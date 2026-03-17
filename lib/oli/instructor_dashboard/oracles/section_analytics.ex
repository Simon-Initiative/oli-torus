defmodule Oli.InstructorDashboard.Oracles.SectionAnalytics do
  @moduledoc """
  Oracle boundary for instructor dashboard section analytics queries.

  Covered dashboard consumers must call this module (or shared registry/runtime
  contracts) instead of invoking `Oli.Analytics.ClickhouseAnalytics` directly.
  """

  use Oli.Dashboard.Oracle

  alias Oli.Analytics.ClickhouseAnalytics
  alias Oli.Dashboard.OracleContext

  @impl true
  def key, do: :oracle_instructor_section_analytics

  @impl true
  def version, do: 1

  @impl true
  def load(
        %OracleContext{dashboard_context_type: :section, dashboard_context_id: section_id},
        opts
      ) do
    mode = Keyword.get(opts, :mode, :comprehensive)

    case mode do
      :availability ->
        section_analytics_loaded?(section_id)

      :comprehensive ->
        comprehensive_section_analytics(section_id)

      {:query, sql, description} when is_binary(sql) and is_binary(description) ->
        execute_query(sql, description)

      _ ->
        {:error, {:unsupported_mode, mode}}
    end
  end

  def load(%OracleContext{}, opts), do: {:error, {:invalid_context, opts}}

  @spec section_analytics_loaded?(pos_integer()) :: {:ok, boolean()} | {:error, term()}
  def section_analytics_loaded?(section_id),
    do: ClickhouseAnalytics.section_analytics_loaded?(section_id)

  @spec comprehensive_section_analytics(pos_integer()) :: {:ok, map()} | {:error, term()}
  def comprehensive_section_analytics(section_id),
    do: ClickhouseAnalytics.comprehensive_section_analytics(section_id)

  @spec execute_query(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def execute_query(query, description), do: ClickhouseAnalytics.execute_query(query, description)

  @spec raw_events_table() :: String.t()
  def raw_events_table, do: ClickhouseAnalytics.raw_events_table()
end
