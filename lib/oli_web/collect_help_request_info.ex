defmodule OliWeb.CollectHelpRequestInfo do
  def collect(conn) do
    %{
      "section" => Map.get(conn.assigns, :section),
      "user" => Map.get(conn.assigns, :current_author) || Map.get(conn.assigns, :current_user),
      "user_agent" => get_user_agent(conn),
      "ip_address" => get_remote_ip(conn),
      "timestamp" => get_system_local_time(),
      "agent_accept" => get_agent_accept(conn),
      "agent_language" => get_agent_language(conn),
      "context" => get_context(conn)
    }
  end

  defp get_context(conn) do
    OliWeb.Common.SessionContext.init(conn)
  end

  defp get_user_agent(conn) do
    user_agent = Enum.at(Plug.Conn.get_req_header(conn, "user-agent"), 0)
    if user_agent === nil, do: "", else: user_agent
  end

  defp get_agent_accept(conn) do
    accept = Enum.at(Plug.Conn.get_req_header(conn, "accept"), 0)
    if accept === nil, do: "", else: accept
  end

  defp get_agent_language(conn) do
    accept_language = Enum.at(Plug.Conn.get_req_header(conn, "accept-language"), 0)
    if accept_language === nil, do: "", else: accept_language
  end

  defp get_remote_ip(conn) do
    conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
  end

  defp get_system_local_time() do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    naive_datetime = NaiveDateTime.from_erl!({{year, month, day}, {hour, minute, second}})
    NaiveDateTime.to_string(naive_datetime)
  end
end
