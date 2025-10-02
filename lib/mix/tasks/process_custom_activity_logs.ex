defmodule Mix.Tasks.ProcessCustomActivityLogs do
  @shortdoc "Process custom activity logs XML data using SweetXml"
  @moduledoc """
  This task reads from the custom_activity_logs table and processes the XML info column and outputs datashop XML.

  ## Usage

      mix process_custom_activity_logs
      mix process_custom_activity_logs --section-id 123 --limit 100
      mix process_custom_activity_logs --section-id 8 --xml-output results.xml --limit 10
      mix process_custom_activity_logs --action "problem_hint_msg" --xml-output results.xml
  """

  use Mix.Task

  alias Oli.Repo
  alias Oli.Delivery.CustomLogs.CustomActivityLog

  import Ecto.Query
  import SweetXml

  require Logger

  @impl Mix.Task
  def run(args) do
    # Parse command line arguments first
    opts = parse_args(args)

    if opts[:help] do
      print_help()
      System.halt(0)
    end

    # Start minimal application dependencies for database access
    start_dependencies()

    # Process the logs
    process_logs(opts)
  end

  defp parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          section_id: :integer,
          user_id: :integer,
          action: :string,
          activity_type: :string,
          limit: :integer,
          xml_output: :string,
          verbose: :boolean,
          help: :boolean
        ],
        aliases: [
          s: :section_id,
          u: :user_id,
          a: :action,
          t: :activity_type,
          l: :limit,
          x: :xml_output,
          v: :verbose,
          h: :help
        ]
      )

    opts
  end

  defp start_dependencies do
    # Start only the essential applications for database access
    # This avoids issues with Vault and other components that require full env setup
    {:ok, _} = Application.ensure_all_started(:logger)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)

    # Start the repo
    Oli.Repo.start_link()
  end

  defp process_logs(opts) do
    Logger.info("Starting custom activity logs processing...")

    # Build query based on options
    query = build_query(opts)

    # Process logs in streaming fashion to avoid memory exhaustion
    case opts[:xml_output] do
      nil ->
        # Just process without collecting results
        Repo.transaction(fn ->
          query
          |> Repo.stream()
          |> Stream.map(&process_single_log(&1, opts))
          |> Stream.filter(&tutor_message?/1)
          |> Stream.run()
        end)

      filename ->
        # Stream process and write directly to file
        stream_export_to_xml(query, filename, opts)
    end

    Logger.info("Processing completed")
  end

  # Check if message is a tutor-related message type
  defp tutor_message?(message) do
    ["<context_message", "<tutor_message", "<tool_message"]
    |> Enum.any?(&String.starts_with?(message, &1))
  end

  defp build_query(opts) do
    query = from(log in CustomActivityLog)

    query =
      case opts[:section_id] do
        nil -> query
        section_id -> from(log in query, where: log.section_id == ^section_id)
      end

    query =
      case opts[:user_id] do
        nil -> query
        user_id -> from(log in query, where: log.user_id == ^user_id)
      end

    query =
      case opts[:action] do
        nil -> query
        action -> from(log in query, where: log.action == ^action)
      end

    query =
      case opts[:activity_type] do
        nil -> query
        activity_type -> from(log in query, where: log.activity_type == ^activity_type)
      end

    query =
      case opts[:limit] do
        nil -> query
        limit -> from(log in query, limit: ^limit)
      end

    from(log in query, order_by: [desc: log.inserted_at])
  end

  defp process_single_log(log, opts) do
    if opts[:verbose] do
      IO.puts("Processing log ID: #{log.id}, Action: #{log.action}")
    end

    # Process the XML info using the same logic as LegacyLogsController
    process_xml_info(log.info, opts)
  end

  defp process_xml_info(xml_string, opts) when is_binary(xml_string) do
    try do
      # Parse the XML document
      doc = xml_string

      # Extract key information using the same XPath patterns as LegacyLogsController
      activity_attempt_guid = extract_safe(doc, ~x"//*/@external_object_id"s)
      action = extract_safe(doc, ~x"//*/@action_id"s)
      info_type = extract_safe(doc, ~x"//*/@info_type"s)

      if opts[:verbose] do
        IO.puts("  Info type: #{info_type}")
        IO.puts("  Activity attempt GUID: #{activity_attempt_guid}")
        IO.puts("  Action: #{action}")
      end

      # Process based on info_type, matching LegacyLogsController logic
      message =
        extract_message(doc)
        |> URI.decode()
        |> extract_sequence()

      message
    rescue
      error ->
        Logger.error("Error processing XML for log: #{inspect(error)}")

        %{
          success: false,
          error: inspect(error),
          raw_xml_preview: String.slice(xml_string, 0, 200) <> "..."
        }
    end
  end

  defp process_xml_info(nil, _opts) do
    %{success: false, error: "XML info is nil"}
  end

  defp process_xml_info(info, _opts) do
    %{success: false, error: "XML info is not a string: #{inspect(info)}"}
  end

  defp extract_message(doc) do
    # Convert doc to string if it's a list
    doc_string =
      case doc do
        doc when is_binary(doc) -> doc
        doc when is_list(doc) -> Enum.join(doc, "")
        _ -> to_string(doc)
      end

    supplement_pattern = ~r/<log_supplement[^>]*>(.*?)<\/log_supplement>/s
    action_pattern = ~r/<log_action[^>]*>(.*?)<\/log_action>/s

    with nil <- Regex.run(supplement_pattern, doc_string, capture: :all_but_first),
         nil <- Regex.run(action_pattern, doc_string, capture: :all_but_first) do
      ""
    else
      [inner_content] -> String.trim(inner_content)
    end
  end

  defp extract_sequence(log_action) do
    # Return early if log_action is empty
    if log_action == "" or is_nil(log_action) do
      ""
    else
      # Use regex to extract content between tutor_related_message_sequence tags
      # This is much simpler and more reliable than xpath for this specific case
      pattern = ~r/<tutor_related_message_sequence[^>]*>(.*?)<\/tutor_related_message_sequence>/s

      case Regex.run(pattern, log_action, capture: :all_but_first) do
        [inner_content] -> String.trim(inner_content)
        _ -> log_action
      end
    end
  end

  # Safe extraction that handles nil results
  defp extract_safe(doc, xpath) do
    try do
      result = xpath(doc, xpath)
      if result == nil, do: "", else: to_string(result)
    rescue
      error ->
        IO.inspect("error extracting safe: #{inspect(error)}")
        ""
    end
  end

  defp stream_export_to_xml(query, filename, opts) do
    Logger.info("Streaming export to XML format: #{filename}")

    # Sanitize filename to prevent directory traversal attacks
    sanitized_filename = sanitize_filename(filename)

    # Prepare output file in secure directory
    base_path = Path.expand("./datashop_output")
    File.mkdir_p!(base_path)
    full_filename = Path.join(base_path, sanitized_filename)

    xml_header =
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<tutor_related_message_sequence version_number=\"4\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"http://pslcdatashop.org/dtd/tutor_message_v4.xsd\">\n"

    xml_footer = "\n</tutor_related_message_sequence>"

    # Stream process and write directly to file
    {count, _} =
      Repo.transaction(fn ->
        File.open!(full_filename, [:write], fn file ->
          # Write header
          IO.binwrite(file, xml_header)

          # Stream process and write each message
          count =
            query
            |> Repo.stream()
            |> Stream.map(&process_single_log(&1, opts))
            |> Stream.filter(&tutor_message?/1)
            |> Stream.with_index()
            |> Enum.reduce(0, fn {message, index}, acc ->
              # Add newline separator for messages after the first
              if index > 0, do: IO.binwrite(file, "\n")
              IO.binwrite(file, message)
              acc + 1
            end)

          # Write footer
          IO.binwrite(file, xml_footer)
          count
        end)
      end)

    Logger.info("Exported #{count} records to XML file #{full_filename}")
  end

  # Sanitize filename to prevent directory traversal attacks
  defp sanitize_filename(filename) do
    # Extract just the basename to remove any directory components
    basename = Path.basename(filename)

    # Remove or replace dangerous characters
    basename
    # Replace non-alphanumeric chars (except dash, underscore, dot)
    |> String.replace(~r/[^\w\-_\.]/, "_")
    # Replace multiple dots with single dot
    |> String.replace(~r/\.{2,}/, ".")
    # Remove leading/trailing dots
    |> String.trim(".")
    |> case do
      # Default filename if sanitization results in empty string
      "" -> "output.xml"
      sanitized -> sanitized
    end
  end

  defp print_help do
    IO.puts("""
    Usage: mix process_custom_activity_logs [options]

    This task processes XML data from the custom_activity_logs table and outputs datashop XML.

    Options:
      -s, --section-id ID      Filter by section ID
      -u, --user-id ID         Filter by user ID
      -a, --action ACTION      Filter by action type
      -t, --activity-type TYPE Filter by activity type
      -l, --limit N            Limit number of records (default: no limit)
      -x, --xml-output FILE    Export results to XML file (tutor_related_message_sequence format)
      -v, --verbose            Show verbose output during processing
      -h, --help               Show this help

    Examples:
      mix process_custom_activity_logs
      mix process_custom_activity_logs --section-id 123 --limit 100 --verbose
      mix process_custom_activity_logs --action "problem_hint_msg" --xml-output results.xml
      mix process_custom_activity_logs --activity-type "oli_multiple_choice" --limit 50
      mix process_custom_activity_logs --section-id 123 --xml-output tutor_messages.xml
    """)
  end
end
