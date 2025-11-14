defmodule Oli.FeatureGate do
  @moduledoc """
  Convenience helpers that bridge `Oli.ScopedFeatureFlags` with telemetry tagging.

  Call `stage/3` from controllers, LiveViews, background jobs, or any other context
  to compute a rollout stage label that can be passed into `Oli.FeatureTelemetry.span/5`.
  """

  alias Phoenix.LiveView.Socket
  alias Plug.Conn
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.ScopedFeatureFlags

  @type stage_tag :: String.t()
  @type feature_name :: atom() | String.t()

  @assign_priority [:feature_gate_resource, :feature_scope, :section, :project, :resource]

  @default_stage "internal"

  @doc """
  Determines the rollout stage tag for a feature within the context provided.

  Accepts a `Plug.Conn`, `Phoenix.LiveView.Socket`, `Project`, `Section`, or an
  explicit resource via `opts[:resource]`. When no scope information is available,
  the configured default (\"internal\") is returned.
  """
  @spec stage(Conn.t() | Socket.t() | struct() | nil, feature_name, keyword()) ::
          stage_tag
  def stage(context, feature, opts \\ [])

  def stage(%Conn{} = conn, feature, opts) do
    conn.assigns
    |> resolve_resource(opts)
    |> compute_stage(feature, opts)
  end

  def stage(%Socket{} = socket, feature, opts) do
    socket.assigns
    |> resolve_resource(opts)
    |> compute_stage(feature, opts)
  end

  def stage(resource, feature, opts) do
    compute_stage(resource, feature, opts)
  end

  @spec enabled?(String.t()) :: boolean
  def enabled?("off"), do: false
  def enabled?(_), do: true

  defp resolve_resource(assigns, opts) when is_map(assigns) do
    opts[:resource] ||
      Enum.find_value(@assign_priority, fn key -> Map.get(assigns, key) end)
  end

  defp resolve_resource(_assigns, opts), do: opts[:resource]

  defp compute_stage(nil, _feature, opts), do: default_stage(opts)

  defp compute_stage(%Project{} = project, feature, opts),
    do: snapshot_stage(feature, project, opts)

  defp compute_stage(%Section{} = section, feature, opts),
    do: snapshot_stage(feature, section, opts)

  defp compute_stage(_unsupported, _feature, opts), do: default_stage(opts)

  defp snapshot_stage(feature, resource, opts) do
    bypass_cache? = Keyword.get(opts, :bypass_cache, false)

    case ScopedFeatureFlags.rollout_snapshot(feature, resource, bypass_cache: bypass_cache?) do
      {:ok, %{effective_stage: stage}} -> format_stage(stage)
      {:error, _} -> default_stage(opts)
    end
  end

  defp format_stage(:internal_only), do: "internal"
  defp format_stage(:five_percent), do: "5"
  defp format_stage(:fifty_percent), do: "50"
  defp format_stage(:full), do: "100"
  defp format_stage(:off), do: "off"
  defp format_stage(stage) when is_atom(stage), do: Atom.to_string(stage)
  defp format_stage(stage) when is_binary(stage), do: stage
  defp format_stage(_stage), do: @default_stage

  defp default_stage(opts), do: Keyword.get(opts, :default_stage, @default_stage)
end
