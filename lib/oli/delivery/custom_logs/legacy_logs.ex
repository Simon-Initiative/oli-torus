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
  alias Oli.Analytics.XAPI.Events.Attempt.TutorMessage
  alias Oli.Analytics.XAPI.StatementBundle
  alias Oli.Analytics.XAPI.Events.Context

  import SweetXml

  @chars "abcdefghijklmnopqrstuvwxyz1234567890" |> String.split("", trim: true)

  def create(doc, host_name) do
    activity_attempt_guid = to_string(xpath(doc, ~x"//*/@external_object_id"))
    action = to_string(xpath(doc, ~x"//*/@action_id"))

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
        join: r1 in Revision,
        on: ra.revision_id == r1.id,
        join: r2 in Revision,
        on: aa.revision_id == r2.id,
        join: at in assoc(r2, :activity_type),
        where: aa.attempt_guid == ^activity_attempt_guid,
        select: {aa, ra, a, r1, sr.project_id, spp.publication_id, s, at}
      )
      |> Repo.one()

    # TODO: Remove this once we have a way to send the activity log to xapi repository.
    # Keep for now until we are relatively sure it does not impact ongoing courses.
    to_attrs(result, action, doc)
    |> create_activity_log()

    send_to_xapi(result, host_name, doc)
  end

  def send_to_xapi(
        {
          activity_attempt,
          resource_attempt,
          resource_access,
          resource_revision,
          project_id,
          publication_id,
          section,
          _activity_type
        },
        host_name,
        doc
      ) do
    message =
      extract_message(doc)
      |> safe_uri_decode()
      |> extract_sequence()

    if tutor_message?(message) do
      # Wrap the message in a message tag
      message = "<message>#{message}</message>"

      context = %Context{
        user_id: resource_access.user_id,
        host_name: host_name,
        section_id: section.id,
        project_id: project_id,
        publication_id: publication_id
      }

      details = %{
        attempt_guid: resource_attempt.attempt_guid,
        attempt_number: resource_attempt.attempt_number,
        resource_id: resource_access.resource_id,
        message: message,
        timestamp: DateTime.utc_now()
      }

      event = TutorMessage.new(context, activity_attempt, details)

      %StatementBundle{
        body: [event] |> Oli.Analytics.Common.to_jsonlines(),
        bundle_id:
          create_bundle_id([resource_revision.resource_id, section.id, random_string(10)]),
        partition_id: context.section_id,
        category: :tutor_message,
        partition: :section
      }
      |> Oli.Analytics.XAPI.emit()
    else
      # we will not send any events for other types of messages
      :ok
    end
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

  # Check if message is a tutor-related message type
  defp tutor_message?(message) do
    ["<context_message", "<tutor_message", "<tool_message"]
    |> Enum.any?(&String.starts_with?(message, &1))
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

  # Updated to handle the 8-element tuple from the optimized query
  defp to_attrs(
         {
           activity_attempt,
           resource_attempt,
           resource_access,
           _resource_revision,
           _project_id,
           _publication_id,
           _section,
           activity_type
         },
         action,
         info
       ) do
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
      activity_type: activity_type.slug,
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

  # Safely decode URI-encoded strings, falling back to original string on error
  defp safe_uri_decode(string) do
    try do
      URI.decode(string)
    rescue
      ArgumentError -> string
    end
  end
end
