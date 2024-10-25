defmodule Oli.Analytics.XAPI do
  @chars "abcdefghijklmnopqrstuvwxyz1234567890" |> String.split("", trim: true)

  @valid_video_attrs MapSet.new([
                       "video_url",
                       "video_title",
                       "video_length",
                       "video_played_segments",
                       "video_progress",
                       "video_time",
                       "content_element_id",
                       "video_play_time",
                       "video_seek_from",
                       "video_seek_to"
                     ])

  import Ecto.Query
  alias Oli.Analytics.XAPI.Events.Context
  alias Oli.Analytics.XAPI.StatementBundle

  def emit(%StatementBundle{} = bundle) do
    config = Application.fetch_env!(:oli, :xapi_upload_pipeline)

    if !Keyword.get(config, :suppress_event_emitting, false) do
      producer =
        Oli.Analytics.XAPI.UploadPipeline
        |> Broadway.producer_names()
        |> Enum.random()

      GenStage.cast(producer, {:insert, bundle})
    else
      :ok
    end
  end

  def emit(category, events) when is_list(events) do
    context = hd(events) |> extract_context()

    %StatementBundle{
      body: events |> Oli.Analytics.Common.to_jsonlines(),
      bundle_id: context.bundle_id,
      partition_id: context.section_id,
      category: category,
      # TODO, we will want to detect the partition once we start
      partition: :section
      # emitting from the authoring side
    }
    |> emit()
  end

  def emit(category, event), do: emit(category, [event])

  defp extract_context(event) do
    section_id = event["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"]

    guid =
      Map.get(
        event["context"]["extensions"],
        "http://oli.cmu.edu/extensions/page_attempt_guid",
        UUID.uuid4()
      )

    bundle_id =
      :crypto.hash(:md5, guid <> "-" <> random_string(10))
      |> Base.encode16()

    %{section_id: section_id, bundle_id: bundle_id}
  end

  def construct_bundle(
        %{
          "category" => "video",
          "event_type" => event_type,
          "host_name" => host_name,
          "key" => %{"page_attempt_guid" => page_attempt_guid}
        } = event,
        expected_user_id
      )
      when event_type in ["played", "paused", "completed", "seeked"] do
    # From the page_attempt_guid, we can issue a single query to get
    # the context for the video event plus the page_attempt_number and page
    # resource_id

    # only get the latest attempt for the page if there are multiple attempts
    query =
      from p in Oli.Delivery.Attempts.Core.ResourceAttempt,
        join: a in Oli.Delivery.Attempts.Core.ResourceAccess,
        on: p.resource_access_id == a.id,
        join: spp in Oli.Delivery.Sections.SectionsProjectsPublications,
        on: a.section_id == spp.section_id,
        join: sr in Oli.Delivery.Sections.SectionResource,
        on: a.resource_id == sr.resource_id and a.section_id == sr.section_id,
        where: p.attempt_guid == ^page_attempt_guid,
        order_by: [desc: p.attempt_number],
        limit: 1,
        select:
          {p.attempt_number, a.resource_id, a.section_id, a.user_id, sr.project_id,
           spp.publication_id}

    case Oli.Repo.one(query) do
      nil ->
        {:error, "page attempt not found"}

      {page_attempt_number, page_id, section_id, ^expected_user_id, project_id, publication_id} ->
        context = %Context{
          user_id: expected_user_id,
          host_name: host_name,
          section_id: section_id,
          project_id: project_id,
          publication_id: publication_id
        }

        details =
          Enum.reduce(event, %{}, fn {k, v}, acc ->
            if MapSet.member?(@valid_video_attrs, k) do
              Map.put(acc, String.to_atom(k), v)
            else
              acc
            end
          end)
          |> Map.merge(%{
            attempt_guid: page_attempt_guid,
            attempt_number: page_attempt_number,
            resource_id: page_id,
            timestamp: DateTime.utc_now()
          })

        event =
          case event_type do
            "played" -> Oli.Analytics.XAPI.Events.Video.Played.new(context, details)
            "paused" -> Oli.Analytics.XAPI.Events.Video.Paused.new(context, details)
            "completed" -> Oli.Analytics.XAPI.Events.Video.Completed.new(context, details)
            "seeked" -> Oli.Analytics.XAPI.Events.Video.Seeked.new(context, details)
          end

        content_element_id = Map.get(details, :content_element_id, "unknown")

        {:ok,
         %StatementBundle{
           body: [event] |> Oli.Analytics.Common.to_jsonlines(),
           bundle_id:
             create_bundle_id([page_attempt_guid, content_element_id, random_string(10)]),
           partition_id: context.section_id,
           category: :video,
           partition: :section
         }}

      _ ->
        {:error, "user id mismatch"}
    end
  end

  def construct_bundle(
        %{
          "category" => "video",
          "event_type" => event_type,
          "host_name" => host_name,
          "key" => %{"resource_id" => resource_id, "section_id" => section_id}
        } = event,
        expected_user_id
      )
      when event_type in ["played", "paused", "completed", "seeked"] do
    query =
      from s in Oli.Delivery.Sections.Section,
        join: spp in Oli.Delivery.Sections.SectionsProjectsPublications,
        on: s.id == spp.section_id,
        join: sr in Oli.Delivery.Sections.SectionResource,
        on: s.id == sr.section_id,
        join: e in Oli.Delivery.Sections.Enrollment,
        on: s.id == e.section_id,
        where:
          sr.resource_id == ^resource_id and e.user_id == ^expected_user_id and
            s.id == ^section_id,
        select: {sr.project_id, spp.publication_id}

    case Oli.Repo.one(query) do
      nil ->
        {:error, "section resource not found"}

      {project_id, publication_id} ->
        context = %Context{
          user_id: expected_user_id,
          host_name: host_name,
          section_id: section_id,
          project_id: project_id,
          publication_id: publication_id
        }

        details =
          Enum.reduce(event, %{}, fn {k, v}, acc ->
            if MapSet.member?(@valid_video_attrs, k) do
              Map.put(acc, String.to_atom(k), v)
            else
              acc
            end
          end)
          |> Map.merge(%{
            attempt_guid: nil,
            attempt_number: nil,
            resource_id: resource_id,
            timestamp: DateTime.utc_now()
          })

        event =
          case event_type do
            "played" -> Oli.Analytics.XAPI.Events.Video.Played.new(context, details)
            "paused" -> Oli.Analytics.XAPI.Events.Video.Paused.new(context, details)
            "completed" -> Oli.Analytics.XAPI.Events.Video.Completed.new(context, details)
            "seeked" -> Oli.Analytics.XAPI.Events.Video.Seeked.new(context, details)
          end

        content_element_id = Map.get(details, :content_element_id, "unknown")

        {:ok,
         %StatementBundle{
           body: [event] |> Oli.Analytics.Common.to_jsonlines(),
           bundle_id:
             create_bundle_id([resource_id, section_id, content_element_id, random_string(10)]),
           partition_id: context.section_id,
           category: :video,
           partition: :section
         }}
    end
  end

  def construct_bundle(_, _), do: {:error, "Unsupported XAPI statement build request"}

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
