defmodule OliWeb.Plugs.AdminWorkspaceLayout do
  @moduledoc """
  Ensures controller-rendered admin routes participate in the shared workspace shell.
  """

  import Plug.Conn

  import Phoenix.Controller, only: [current_path: 1, put_layout: 2, put_root_layout: 2]

  alias Oli.Accounts
  alias OliWeb.Admin.AdminView

  def init(opts), do: opts

  def call(conn, _opts) do
    breadcrumbs = conn.assigns[:breadcrumbs] || AdminView.breadcrumb()

    conn
    |> put_root_layout(html: {OliWeb.LayoutView, :delivery})
    |> put_layout(html: {OliWeb.Layouts, :workspace})
    |> assign_if_missing(:active_workspace, fn -> :admin end)
    |> assign_if_missing(:active_view, fn -> conn.assigns[:active] || :admin end)
    |> assign_if_missing(:sidebar_expanded, fn -> true end)
    |> assign_if_missing(:disable_sidebar?, fn -> false end)
    |> assign_if_missing(:footer_enabled?, fn -> true end)
    |> assign_if_missing(:preview_mode, fn -> false end)
    |> assign_if_missing(:is_admin, fn ->
      case {conn.assigns[:is_admin], conn.assigns[:current_author]} do
        {true, _} -> true
        {false, %{} = author} -> Accounts.is_admin?(author)
        {nil, %{} = author} -> Accounts.is_admin?(author)
        _ -> false
      end
    end)
    |> assign_if_missing(:uri, fn -> current_path(conn) end)
    |> assign(:breadcrumbs, breadcrumbs)
  end

  defp assign_if_missing(conn, key, fun) do
    case conn.assigns do
      %{^key => value} when not is_nil(value) -> conn
      _ -> assign(conn, key, fun.())
    end
  end
end
