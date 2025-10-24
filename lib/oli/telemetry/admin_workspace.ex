defmodule Oli.Telemetry.AdminWorkspace do
  @moduledoc false

  alias OliWeb.Common.SessionContext

  @nav_event [:oli, :admin_workspace, :nav_click]
  @breadcrumb_event [:oli, :admin_workspace, :breadcrumb_use]

  @doc """
  Emit telemetry when an admin workspace navigation occurs.
  """
  @spec nav_click(SessionContext.t(), String.t() | nil, String.t(), atom(), atom()) :: :ok
  def nav_click(ctx, from, to, route_type, source \\ :nav)

  def nav_click(%SessionContext{} = ctx, from, to, route_type, source) when is_binary(to) do
    metadata = %{
      user_id: user_id(ctx),
      institution_id: institution_id(ctx),
      from: from,
      to: to,
      route_type: if(is_atom(route_type), do: Atom.to_string(route_type), else: route_type),
      source: if(is_atom(source), do: Atom.to_string(source), else: source),
      theme: theme(ctx),
      feature_flag_version: feature_flag_version()
    }

    :telemetry.execute(@nav_event, %{count: 1}, metadata)
  end

  def nav_click(_, _, _, _, _), do: :ok

  @doc """
  Emit telemetry when an admin breadcrumb is followed.
  """
  @spec breadcrumb_use(SessionContext.t(), String.t() | nil, String.t()) :: :ok
  def breadcrumb_use(%SessionContext{} = ctx, from, to) when is_binary(to) do
    metadata = %{
      user_id: user_id(ctx),
      institution_id: institution_id(ctx),
      from: from,
      to: to,
      theme: theme(ctx),
      feature_flag_version: feature_flag_version()
    }

    :telemetry.execute(@breadcrumb_event, %{count: 1}, metadata)
  end

  def breadcrumb_use(_, _, _), do: :ok

  defp user_id(%SessionContext{author: %{id: id}}) when not is_nil(id), do: id
  defp user_id(%SessionContext{user: %{id: id}}) when not is_nil(id), do: id
  defp user_id(_), do: nil

  defp institution_id(%SessionContext{user: %{lti_institution_id: lti_id}})
       when not is_nil(lti_id),
       do: lti_id

  defp institution_id(_), do: nil

  defp theme(_), do: nil

  defp feature_flag_version do
    Application.get_env(:oli, :admin_workspace_feature_flag_version, nil)
  end
end
