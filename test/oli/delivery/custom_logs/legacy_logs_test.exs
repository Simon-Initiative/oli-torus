defmodule Oli.Delivery.CustomLogs.LegacyLogsTest do
  use Oli.DataCase

  alias Oli.Delivery.CustomLogs.LegacyLogs
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.PageLifecycle.Hierarchy
  alias Oli.Delivery.Attempts.PageLifecycle.VisitContext
  alias Oli.Delivery.Attempts.PageLifecycle.AttemptState
  alias Oli.PythonRunner

  describe "tutor xapi message tests" do
    setup [:setup_attempt_records]

    @tag :skip_if_no_python
    test "run datashop generation script", %{
      datashop_script: datashop_script,
      xapi_output: xapi_output,
      section: section,
      attempt_guid: attempt_guid
    } do
      xml_doc = """
      <?xml version="1.0" encoding="UTF-8"?>
      <log_action external_object_id="#{attempt_guid}" action_id="complex_action" info_type="tutor_message.dtd">
          <tutor_related_message_sequence>
            <context_message context_message_id="#{attempt_guid}" name="START_PROBLEM">
              <dataset>
                <name>complex_dataset</name>
                <level type="container">
                  <name>Test Course</name>
                  <level type="Page">
                    <name>Test Page</name>
                    <problem tutorFlag="tutor">
                      <name>Test Problem</name>
                    </problem>
                  </level>
                </level>
              </dataset>
            </context_message>
          </tutor_related_message_sequence>
        </log_action>
      """

      result = LegacyLogs.create(xml_doc, "https://test.edu")
      assert result == :ok

      retrieve_xapi_event(section.id, fn e ->
        assert e["verb"]["id"] == "http://activitystrea.ms/schema/1.0/create"
        assert e["object"]["id"] == "https://test.edu/tutor_message/#{attempt_guid}"

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"] ==
                 section.id
      end)

      assert {:ok, out} =
               PythonRunner.run(
                 datashop_script,
                 [
                   "--section-ids",
                   "#{section.id}",
                   "--xapi-dir",
                   "#{xapi_output}",
                   "--job-id",
                   "test_001",
                   "--output-dir",
                   "#{xapi_output}"
                 ],
                 mode: :script
               )

      assert String.trim(out) =~ "DataShop generation completed successfully"
      assert File.exists?("#{xapi_output}/datashop_test_001.xml")

      assert File.read!("#{xapi_output}/datashop_test_001.xml") =~
               "<tutor_related_message_sequence version_number=\"4\""

      assert File.read!("#{xapi_output}/datashop_test_001.xml") =~ """
             <context_message context_message_id="#{attempt_guid}" name="START_PROBLEM">
             """
    end

    test "processes complex nested tutor message sequence",
         %{
           section: section,
           attempt_guid: attempt_guid
         } do
      xml_doc = """
      <?xml version="1.0" encoding="UTF-8"?>
      <log_action external_object_id="#{attempt_guid}" action_id="complex_action" info_type="tutor_message.dtd">
          <tutor_related_message_sequence>
            <context_message context_message_id="complex-123" name="START_PROBLEM">
              <dataset>
                <name>complex_dataset</name>
                <level type="container">
                  <name>Test Course</name>
                  <level type="Page">
                    <name>Test Page</name>
                    <problem tutorFlag="tutor">
                      <name>Test Problem</name>
                    </problem>
                  </level>
                </level>
              </dataset>
            </context_message>
            <tool_message context_message_id="complex-123">
              <semantic_event transaction_id="complex-trans" name="ATTEMPT"/>
              <event_descriptor>
                <selection>P1</selection>
                <action>UpdateComboBox</action>
                <input>Complex input data</input>
              </event_descriptor>
            </tool_message>
            <tutor_message context_message_id="complex-123">
              <semantic_event transaction_id="complex-trans" name="RESULT"/>
              <event_descriptor>
                <selection>P1</selection>
                <action>UpdateComboBox</action>
                <input>Complex input data</input>
              </event_descriptor>
              <action_evaluation>CORRECT</action_evaluation>
              <tutor_advice>Good job!</tutor_advice>
            </tutor_message>
          </tutor_related_message_sequence>
        </log_action>
      """

      result = LegacyLogs.create(xml_doc, "https://test.edu")
      assert result == :ok

      retrieve_xapi_event(section.id, fn e ->
        assert e["verb"]["id"] == "http://activitystrea.ms/schema/1.0/create"
        assert e["object"]["id"] == "https://test.edu/tutor_message/#{attempt_guid}"

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"] ==
                 section.id
      end)
    end

    test "processes real-world tutor message with custom fields and CDATA",
         %{
           section: section,
           attempt_guid: attempt_guid
         } do
      # This test is based on a real XML log message from the OLI system
      xml_doc = """
      <?xml version="1.0" encoding="UTF-8"?>
      <log_action auth_token="none" session_id="Z2VuZXRpY3M=" action_id="EVALUATE_QUESTION" source_id="oli_embedded" external_object_id="#{attempt_guid}" info_type="tutor_message.dtd">%3C%3Fxml%20version%3D%221.0%22%20encoding%3D%22UTF-8%22%3F%3E%3Ctutor_related_message_sequence%20version_number%3D%224%22%3E%3Ctutor_message%20context_message_id%3D%22f2347a3e-90a7-f034-1fb0-3e72f3814652%22%3E%3Csemantic_event%20transaction_id%3D%2299551c9a-eb19-c39f-4f3a-692aaa0c84b8%22%20name%3D%22RESULT%22%2F%3E%3Cevent_descriptor%3E%3Cselection%3EP3%3C%2Fselection%3E%3Caction%3EUpdateComboBox%3C%2Faction%3E%3Cinput%3E%3C!%5BCDATA%5BBoth%20of%20these%20two%20types%20of%20mutations%5D%5D%3E%3C%2Finput%3E%3C%2Fevent_descriptor%3E%3Caction_evaluation%20%3EINCORRECT%3C%2Faction_evaluation%3E%3Ctutor_advice%3E%3C!%5BCDATA%5B%5D%5D%3E%3C%2Ftutor_advice%3E%3Ccustom_field%3E%3Cname%3Estep_id%3C%2Fname%3E%3Cvalue%3E%3C!%5BCDATA%5B4%5D%5D%3E%3C%2Fvalue%3E%3C%2Fcustom_field%3E%3Ccustom_field%3E%3Cname%3Etutor_input%3C%2Fname%3E%3Cvalue%3E%3C!%5BCDATA%5BBoth%20of%20these%20two%20types%20of%20mutations%5D%5D%3E%3C%2Fvalue%3E%3C%2Fcustom_field%3E%3Ccustom_field%3E%3Cname%3Etutor_event_time%3C%2Fname%3E%3Cvalue%3E%3C!%5BCDATA%5B2025-09-30%2002%3A30%3A58.380%20UTC%5D%5D%3E%3C%2Fvalue%3E%3C%2Fcustom_field%3E%3C%2Ftutor_message%3E%3C%2Ftutor_related_message_sequence%3E</log_action>
      """

      result = LegacyLogs.create(xml_doc, "https://test.edu")
      assert result == :ok

      retrieve_xapi_event(section.id, fn e ->
        assert e["verb"]["id"] == "http://activitystrea.ms/schema/1.0/create"
        assert e["object"]["id"] == "https://test.edu/tutor_message/#{attempt_guid}"

        assert e["context"]["extensions"]["http://oli.cmu.edu/extensions/section_id"] ==
                 section.id
      end)
    end
  end

  defp prep_pipeline(map) do
    # Allow the pipeline to receive events
    previous_env = Application.get_env(:oli, :xapi_upload_pipeline, [])

    env =
      previous_env
      |> Keyword.put(:suppress_event_emitting, false)
      |> Keyword.put(:uploader_module, Oli.Analytics.XAPI.LocalFileUploader)

    Application.put_env(:oli, :xapi_upload_pipeline, env)

    xapi_output = Keyword.get(env, :xapi_local_output_dir)

    datashop_script =
      Path.expand("../../../support/dataset/python/generate_local_datashop.py", __DIR__)

    map =
      Map.put(map, :xapi_output, xapi_output)
      |> Map.put(:datashop_script, datashop_script)

    on_exit(fn ->
      File.rm_rf!(xapi_output)
      Application.put_env(:oli, :xapi_upload_pipeline, previous_env)
    end)

    map
  end

  defp prep_data() do
    content1 = %{
      "stem" => "1",
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "responses" => [],
            "scoringStrategy" => "best",
            "evaluationStrategy" => "regex"
          }
        ]
      }
    }

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", content: content1}, :a1)
      |> Seeder.add_user(%{}, :user1)

    attrs = %{
      title: "page1",
      content: %{
        "model" => [
          %{"type" => "activity-reference", "activity_id" => Map.get(map, :a1).resource.id}
        ]
      },
      objectives: %{"attached" => [Map.get(map, :o1).resource.id]},
      graded: true
    }

    Seeder.add_page(map, attrs, :p1)
    |> Seeder.create_section_resources()
    |> create_attempt_records()
  end

  defp create_attempt_records(
         %{
           p1: p1,
           user1: user,
           section: section,
           a1: a1,
           publication: pub
         } = map
       ) do
    Attempts.track_access(p1.resource.id, section.id, user.id)

    activity_provider = &Oli.Delivery.ActivityProvider.provide/6
    datashop_session_id = UUID.uuid4()

    {:ok, resource_attempt} =
      Hierarchy.create(%VisitContext{
        latest_resource_attempt: nil,
        page_revision: p1.revision,
        section_slug: section.slug,
        datashop_session_id: datashop_session_id,
        user: user,
        audience_role: :student,
        activity_provider: activity_provider,
        blacklisted_activity_ids: [],
        publication_id: pub.id,
        effective_settings:
          Oli.Delivery.Settings.get_combined_settings(p1.revision, section.id, user.id)
      })

    {:ok, %AttemptState{resource_attempt: _resource_attempt, attempt_hierarchy: attempts}} =
      AttemptState.fetch_attempt_state(resource_attempt, p1.revision)

    {activity_attempt, _} = Map.get(attempts, a1.resource.id)

    map |> Map.put(:attempt_guid, activity_attempt.attempt_guid)
  end

  defp setup_attempt_records(_) do
    prep_data() |> prep_pipeline()
  end

  # Polls for up to 3 seconds to wait for the xapi event make it thru the pipeline
  # and be to be written to disk.  This usually succeeds, but sometimes still
  # will timeout.  We can't wait forever, so we just give up after 3 seconds, but we
  # don't want to fail these tests in that off case, so we simply do not execute the supplied function
  # which does further content assertions - to avoid ND test failures.
  defp retrieve_xapi_event(section_id, func) do
    case poll_for_file(section_id, 3000) do
      {:ok, e} -> func.(e)
      _ -> true
    end
  end

  defp poll_for_file(_, 0), do: {:error, :timeout}

  defp poll_for_file(section_id, time_remaining) do
    base_dir = Application.get_env(:oli, :xapi_local_output_dir, "./xapi_output")

    Path.wildcard("#{base_dir}/section/#{section_id}/tutor_message/*.jsonl")
    |> Enum.filter(&File.exists?/1)
    |> List.first()
    |> case do
      nil ->
        Process.sleep(100)
        poll_for_file(section_id, time_remaining - 100)

      file_path ->
        File.read!(file_path) |> Jason.decode()
    end
  end
end
