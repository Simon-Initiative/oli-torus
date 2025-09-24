defmodule Oli.Delivery.CustomLogs.LegacyLogs do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Resources.Revision

  alias Oli.Delivery.Attempts.Core.{
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

  alias Oli.Delivery.CustomLogs.CustomActivityLog
  alias Oli.Analytics.XAPI.Events.Attempt.TutorActivityMessage
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Analytics.XAPI.Events.Context

  import SweetXml

  @chars "abcdefghijklmnopqrstuvwxyz1234567890" |> String.split("", trim: true)

  def create(doc, host_name) do
    IO.inspect(host_name, label: "host_name--------------------------------------")
    activity_attempt_guid = to_string(xpath(doc, ~x"//*/@external_object_id"))
    action = to_string(xpath(doc, ~x"//*/@action_id"))

    # Fetch all the necessary context information to be able to create activity log
    result =
      from(
        aa in ActivityAttempt,
        join: ra in ResourceAttempt,
        on: aa.resource_attempt_id == ra.id,
        join: a in ResourceAccess,
        on: ra.resource_access_id == a.id,
        join: s in Oli.Delivery.Sections.Section,
        on: a.section_id == s.id,
        join: spp in Oli.Delivery.Sections.SectionsProjectsPublications,
        on: s.id == spp.section_id,
        join: sr in Oli.Delivery.Sections.SectionResource,
        on: s.id == sr.section_id and a.resource_id == sr.resource_id,
        join: e in Oli.Delivery.Sections.Enrollment,
        on: s.id == e.section_id and a.user_id == e.user_id,
        join: r1 in Revision,
        on: ra.revision_id == r1.id,
        join: r2 in Revision,
        on: aa.revision_id == r2.id,
        where: aa.attempt_guid == ^activity_attempt_guid,
        select: {aa, ra, a, r1, r2, sr.project_id, spp.publication_id, s}
      )
      |> Repo.one()

    send_to_xapi(result, host_name, doc)

    # TODO: Remove this once we have a way to send the activity log to xapi repository
    to_attrs(result, action, doc)
    |> create_activity_log()
  end

  defp send_to_xapi(
         {
           activity_attempt,
           _resource_attempt,
           resource_access,
           resource_revision,
           _activity_revision,
           project_id,
           publication_id,
           section
         },
         host_name,
         doc
       ) do
    info_type = to_string(xpath(doc, ~x"//*/@info_type"))

    message =
      cond do
        info_type == "tutor_message.dtd" or info_type == "tutor_message_v2.dtd" ->
          extract_safe(doc, ~x"//log_action/text()"s)
          |> URI.decode()
          |> process_tutor_related_message_sequence()

        tag_exists?(doc, "log_supplement") ->
          extract_safe(doc, ~x"//log_supplement/text()"s)
          |> URI.decode()
          |> process_tutor_related_message_sequence()

        true ->
          extract_safe(doc, ~x"//log_action/text()"s)
          |> URI.decode()
          |> process_tutor_related_message_sequence()
      end

    if tutor_message?(message) do
      IO.inspect(message, label: "message--------------------------------------")

      context = %Context{
        user_id: resource_access.user_id,
        host_name: host_name,
        section_id: section.id,
        project_id: project_id,
        publication_id: publication_id
      }

      details = %{
        attempt_guid: activity_attempt.attempt_guid,
        attempt_number: activity_attempt.attempt_number,
        resource_id: resource_revision.resource_id,
        message: message,
        timestamp: DateTime.utc_now()
      }

      event = TutorActivityMessage.new(context, activity_attempt, details)

      %StatementBundle{
        body: [event] |> Oli.Analytics.Common.to_jsonlines(),
        bundle_id:
          create_bundle_id([resource_revision.resource_id, section.id, random_string(10)]),
        partition_id: context.section_id,
        category: :tutor_activity_message,
        partition: :section
      }
      |> Oli.Analytics.XAPI.emit()
    else
      # we will not send any events for other types of messages
      :ok
    end
  end

  # Check if message is a tutor-related message type
  defp tutor_message?(message) do
    ["<context_message", "<tutor_message", "<tool_message"]
    |> Enum.any?(&String.starts_with?(message, &1))
  end

  defp process_tutor_related_message_sequence(log_action) do
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

  # Check if a tag exists in the XML, matching LegacyLogsController logic
  defp tag_exists?(xml_content, tag_name) do
    try do
      result = xml_content |> xpath(~x"//#{tag_name}")
      result != nil
    rescue
      _ -> false
    end
  end

  # Updated to handle the 8-element tuple from the enhanced query
  defp to_attrs(
         {
           activity_attempt,
           _resource_attempt,
           resource_access,
           resource_revision,
           activity_revision,
           _project_id,
           _publication_id,
           _section
         },
         action,
         info
       ) do
    activity_revision = Repo.preload(activity_revision, :activity_type)

    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    %{
      resource_id: resource_access.resource_id,
      section_id: resource_access.section_id,
      user_id: resource_access.user_id,
      activity_attempt_id: activity_attempt.id,
      revision_id: activity_attempt.revision_id,
      attempt_number: activity_attempt.attempt_number,
      activity_type: activity_revision.activity_type.slug,
      action: action,
      info: info,
      inserted_at: now,
      updated_at: now
    }
  end

  defp create_activity_log(attrs) do
    %CustomActivityLog{}
    |> CustomActivityLog.changeset(attrs)
    |> Repo.insert()
  end

  defp random_string(length) do
    Enum.reduce(1..length, [], fn _i, acc ->
      [Enum.random(@chars) | acc]
    end)
    |> Enum.join("")
  end

  defp create_bundle_id(some_unique_facts) do
    guids = Enum.join(some_unique_facts, ",")

    :crypto.hash(:md5, guids)
    |> Base.encode16()
  end
end
