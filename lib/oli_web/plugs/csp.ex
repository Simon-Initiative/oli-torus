defmodule OliWeb.Plugs.CSP do
  @moduledoc """
  Sets a Content-Security-Policy header unless one is already present.
  """

  import Plug.Conn

  @csp_header "content-security-policy"

  def init(opts), do: opts

  def call(conn, opts) do
    case get_resp_header(conn, @csp_header) do
      [] ->
        policy =
          opts
          |> Keyword.get(:directives, csp_directives())
          |> serialize_directives()

        put_resp_header(conn, @csp_header, policy)

      _existing ->
        conn
    end
  end

  defp csp_directives do
    Application.get_env(:oli, :csp, [])
    |> Keyword.get(:directives, [])
  end

  defp serialize_directives(directives) when is_map(directives) do
    directives
    |> Enum.to_list()
    |> serialize_directives()
  end

  defp serialize_directives(directives) when is_list(directives) do
    directives
    |> Enum.map(&serialize_directive/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("; ")
  end

  defp serialize_directives(_), do: ""

  defp serialize_directive({directive, true}), do: directive

  defp serialize_directive({directive, values}) when is_binary(values) do
    String.trim("#{directive} #{values}")
  end

  defp serialize_directive({directive, values}) when is_list(values) do
    values =
      values
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(" ")

    String.trim("#{directive} #{values}")
  end

  defp serialize_directive(_), do: ""
end
