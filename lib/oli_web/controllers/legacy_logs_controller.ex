defmodule OliWeb.LegacyLogsController do
  use OliWeb, :controller

  import SweetXml

  def process(conn, _params) do
    doc =
      case Map.get(conn.assigns, :raw_body) do
        nil ->
          {:ok, raw_body, _conn} = Plug.Conn.read_body(conn, length: 20_000_000)
          raw_body

        raw_body ->
          raw_body
      end

    activity_attempt_guid = to_string(xpath(doc, ~x"//*/@external_object_id"))
    action = to_string(xpath(doc, ~x"//*/@action_id"))
    info_type = to_string(xpath(doc, ~x"//*/@info_type"))
    IO.inspect(info_type, label: "info_type--------------------------------------")
    if info_type == "tutor_message.dtd" or info_type == "tutor_message_v2.dtd" do
      # TODO: Process tutor message
      log_action = to_string(xpath(doc, ~x"//log_action/text()")) |> URI.decode()

      IO.inspect(log_action, label: "log_action")

    else
      # TODO: Process other types of logs
      if tag_exists?(doc, "log_supplement") do
        # TODO: Process tutor message
        log_supplement = to_string(xpath(doc, ~x"//log_supplement/text()")) |> URI.decode()
        IO.inspect(log_supplement, label: "log_supplement")
      else
        # TODO: Process other types of logs
        log_action = to_string(xpath(doc, ~x"//log_action/text()")) |> URI.decode()
        IO.inspect(log_action, label: "log_action22")
      end
    end

    # Processing via oban task not neccessary here given that this http request
    # is only involved with this one single task
    Oli.Delivery.CustomLogs.Worker.perform_now(activity_attempt_guid, action, to_string(doc))

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, "status=success")
  end

  defp to_sigil_s(string) when is_binary(string) do
    "~s(#{string})"
  end

  defp tag_exists?(xml_content, tag_name) do
    result = xml_content |> xpath(~x"//#{tag_name}")
    result != nil
  end

  @doc """
  Remove various types of escaped quotes from XML content
  """
  defp clean_quotes(content) when is_binary(content) do
    content
    |> String.replace("\\\"", "\"")    # Replace escaped quotes with regular quotes
    |> String.replace("&quot;", "\"")   # Replace HTML entities
    |> String.replace("&#34;", "\"")    # Replace numeric HTML entities
  end
end
