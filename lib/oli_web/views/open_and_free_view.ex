defmodule OliWeb.OpenAndFreeView do
  use OliWeb, :view

  def get_path([conn_or_action | rest]) do
    if is_admin_path?(conn_or_action) do
      apply(Routes, :admin_open_and_free_path, [OliWeb.Endpoint | rest])
    else
      apply(Routes, :independent_sections_path, [OliWeb.Endpoint | rest])
    end
  end

  def is_admin_path?(conn_or_action = %Plug.Conn{}) do
    Enum.member?(conn_or_action.path_info, "admin")
  end

  def is_admin_path?(:admin = _conn_or_action), do: true
  def is_admin_path?(_), do: false
end
