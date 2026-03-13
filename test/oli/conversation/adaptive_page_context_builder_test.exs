defmodule Oli.Conversation.AdaptivePageContextBuilderTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Conversation.AdaptivePageContextBuilder
  alias Oli.Repo

  describe "build/3" do
    # AC-010: unseen future-screen content remains excluded from adaptive context output.
    test "returns current screen, previously visited screens, and label-only unvisited screens" do
      %{
        section: section,
        user: user,
        current_attempt: current_attempt
      } = adaptive_page_fixture()

      assert {:ok, markdown} =
               AdaptivePageContextBuilder.build(current_attempt.attempt_guid, section.id, user.id)

      assert markdown =~ "## Current screen"
      assert markdown =~ "### Screen 2"
      assert markdown =~ "Current screen prompt"
      assert markdown =~ ~s(- `part_current`: `{"input":"current response"}`)

      assert markdown =~ "## Previously visited screens"
      assert markdown =~ "### Screen 1"
      assert markdown =~ "Visited screen prompt"
      assert markdown =~ ~s(- `part_visited`: `{"input":"visited response"}`)

      assert markdown =~ "## Not yet visited screens"
      assert markdown =~ "Only the labels below are available"
      assert markdown =~ "- Screen 3"
      refute markdown =~ "Future screen prompt"
    end

    test "preserves attempt order for revisits while keeping the current screen separate" do
      %{
        section: section,
        user: user,
        current_attempt: current_attempt
      } = adaptive_page_fixture(revisit_current_screen?: true)

      assert {:ok, markdown} =
               AdaptivePageContextBuilder.build(current_attempt.attempt_guid, section.id, user.id)

      assert markdown =~ ~r/## Current screen\n### Screen 1/s

      assert markdown =~
               ~r/## Previously visited screens\n### Screen 1.*Visited screen prompt.*### Screen 2/s

      assert markdown =~ ~r/revisited response/
      assert length(Regex.scan(~r/^### Screen 1$/m, markdown)) == 2
    end

    test "rejects mismatched learner access" do
      %{section: section, current_attempt: current_attempt} = adaptive_page_fixture()
      other_user = insert(:user)

      assert {:error, :no_access} =
               AdaptivePageContextBuilder.build(
                 current_attempt.attempt_guid,
                 section.id,
                 other_user.id
               )
    end

    test "rejects mismatched section access" do
      %{user: user, current_attempt: current_attempt} = adaptive_page_fixture()

      assert {:error, :no_access} =
               AdaptivePageContextBuilder.build(
                 current_attempt.attempt_guid,
                 -1,
                 user.id
               )
    end

    test "fails closed for unknown attempts" do
      assert {:error, :activity_attempt_not_found} =
               AdaptivePageContextBuilder.build("missing-guid", 1, 1)
    end

    test "fails closed when the page attempt is not adaptive" do
      %{
        section: section,
        user: user,
        current_attempt: current_attempt
      } = adaptive_page_fixture(adaptive_page?: false)

      assert {:error, :not_adaptive_page} =
               AdaptivePageContextBuilder.build(current_attempt.attempt_guid, section.id, user.id)
    end

    test "falls back to ordered attempts when visit state is missing" do
      %{
        section: section,
        user: user,
        resource_attempt: resource_attempt,
        current_attempt: current_attempt
      } = adaptive_page_fixture()

      resource_attempt
      |> Ecto.Changeset.change(state: %{})
      |> Repo.update!()

      assert {:ok, markdown} =
               AdaptivePageContextBuilder.build(current_attempt.attempt_guid, section.id, user.id)

      assert markdown =~ "### Screen 2"
      assert markdown =~ "### Screen 1"
      assert markdown =~ "- Screen 3"
      refute markdown =~ "Future screen prompt"
    end

    test "defaults unvisited screen labels when sequence names are missing" do
      %{
        section: section,
        user: user,
        current_attempt: current_attempt
      } = adaptive_page_fixture(missing_sequence_names?: true)

      assert {:ok, markdown} =
               AdaptivePageContextBuilder.build(current_attempt.attempt_guid, section.id, user.id)

      assert markdown =~ "## Not yet visited screens"
      assert markdown =~ "- Screen 3"
      refute markdown =~ ~r/^- $/m
    end

    test "maps duplicate activity references by occurrence order" do
      %{
        section: section,
        user: user,
        current_attempt: current_attempt
      } = adaptive_page_fixture(duplicate_activity_reference?: true)

      assert {:ok, markdown} =
               AdaptivePageContextBuilder.build(current_attempt.attempt_guid, section.id, user.id)

      assert markdown =~ ~r/## Current screen\n### Screen 3/s

      assert markdown =~
               ~r/## Previously visited screens\n### Screen 1.*### Screen 2/s

      assert length(Regex.scan(~r/^### Screen 1$/m, markdown)) == 1
      assert length(Regex.scan(~r/^### Screen 3$/m, markdown)) == 1
    end
  end

  defp adaptive_page_fixture(opts \\ []) do
    revisit_current_screen? = Keyword.get(opts, :revisit_current_screen?, false)
    adaptive_page? = Keyword.get(opts, :adaptive_page?, true)
    missing_sequence_names? = Keyword.get(opts, :missing_sequence_names?, false)
    duplicate_activity_reference? = Keyword.get(opts, :duplicate_activity_reference?, false)

    section = insert(:section)
    user = insert(:user)

    page_resource = insert(:resource)

    screen_1_revision =
      insert(:revision,
        resource: insert(:resource),
        title: "Screen 1",
        content: screen_content("Visited screen prompt")
      )

    screen_2_revision =
      insert(:revision,
        resource: insert(:resource),
        title: "Screen 2",
        content: screen_content("Current screen prompt")
      )

    screen_3_revision =
      insert(:revision,
        resource: insert(:resource),
        title: "Screen 3",
        content: screen_content("Future screen prompt")
      )

    screen_3_activity_revision =
      if duplicate_activity_reference?, do: screen_1_revision, else: screen_3_revision

    page_revision =
      insert(:revision,
        resource: page_resource,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Adaptive Page",
        content:
          page_content(
            [
              %{
                revision: screen_1_revision,
                sequence_id: "screen-1",
                sequence_name: if(missing_sequence_names?, do: nil, else: "Screen 1")
              },
              %{
                revision: screen_2_revision,
                sequence_id: "screen-2",
                sequence_name: if(missing_sequence_names?, do: nil, else: "Screen 2")
              },
              %{
                revision: screen_3_activity_revision,
                sequence_id: "screen-3",
                sequence_name: if(missing_sequence_names?, do: nil, else: "Screen 3")
              }
            ],
            adaptive_page?
          )
      )

    resource_access =
      insert(:resource_access,
        user: user,
        section: section,
        resource: page_resource
      )

    resource_attempt =
      insert(:resource_attempt,
        resource_access: resource_access,
        revision: page_revision,
        content: page_revision.content,
        state:
          page_attempt_state(
            revisit_current_screen?,
            [
              %{
                sequence_id: "screen-1",
                visit_count: if(revisit_current_screen?, do: 2, else: 1)
              },
              %{sequence_id: "screen-2", visit_count: 1}
            ] ++
              if(duplicate_activity_reference?,
                do: [%{sequence_id: "screen-3", visit_count: 1}],
                else: []
              )
          )
      )

    visited_attempt =
      insert(:activity_attempt,
        resource_attempt: resource_attempt,
        revision: screen_1_revision,
        resource: screen_1_revision.resource,
        attempt_number: 1
      )

    insert(:part_attempt,
      activity_attempt: visited_attempt,
      part_id: "part_visited",
      attempt_number: 1,
      response: %{"input" => "visited response"}
    )

    screen_2_attempt =
      insert(:activity_attempt,
        resource_attempt: resource_attempt,
        revision: screen_2_revision,
        resource: screen_2_revision.resource,
        attempt_number: 1
      )

    insert(:part_attempt,
      activity_attempt: screen_2_attempt,
      part_id: "part_current",
      attempt_number: 1,
      response: %{"input" => "current response"}
    )

    current_attempt =
      case revisit_current_screen? do
        true ->
          revisited_attempt =
            insert(:activity_attempt,
              resource_attempt: resource_attempt,
              revision: screen_1_revision,
              resource: screen_1_revision.resource,
              attempt_number: 2
            )

          insert(:part_attempt,
            activity_attempt: revisited_attempt,
            part_id: "part_revisit",
            attempt_number: 1,
            response: %{"input" => "revisited response"}
          )

          revisited_attempt

        false ->
          if duplicate_activity_reference? do
            duplicate_screen_attempt =
              insert(:activity_attempt,
                resource_attempt: resource_attempt,
                revision: screen_1_revision,
                resource: screen_1_revision.resource,
                attempt_number: 2
              )

            insert(:part_attempt,
              activity_attempt: duplicate_screen_attempt,
              part_id: "part_duplicate",
              attempt_number: 1,
              response: %{"input" => "duplicate screen response"}
            )

            duplicate_screen_attempt
          else
            screen_2_attempt
          end
      end

    %{
      current_attempt: current_attempt,
      page_revision: page_revision,
      resource_attempt: resource_attempt,
      section: section,
      user: user
    }
  end

  defp page_content(sequence_entries, adaptive_page?) do
    base =
      %{
        "displayApplicationChrome" => true,
        "model" => [
          %{
            "type" => "group",
            "layout" => "deck",
            "children" =>
              Enum.map(sequence_entries, fn %{
                                              revision: revision,
                                              sequence_id: sequence_id,
                                              sequence_name: sequence_name
                                            } ->
                %{
                  "type" => "activity-reference",
                  "activity_id" => revision.resource_id,
                  "custom" => %{
                    "sequenceId" => sequence_id,
                    "sequenceName" => sequence_name
                  }
                }
              end)
          }
        ]
      }

    case adaptive_page? do
      true -> Map.put(base, "advancedDelivery", true)
      false -> base
    end
  end

  defp page_attempt_state(_revisit_current_screen?, visits) do
    Enum.with_index(visits, 1)
    |> Enum.reduce(%{}, fn {%{sequence_id: sequence_id, visit_count: visit_count}, index}, acc ->
      acc
      |> Map.put("session.visits.#{sequence_id}", visit_count)
      |> Map.put("session.visitTimestamps.#{sequence_id}", index * 1000)
    end)
  end

  defp screen_content(prompt_text) do
    %{
      "partsLayout" => [
        %{
          "type" => "content",
          "children" => [
            %{"text" => prompt_text}
          ]
        }
      ]
    }
  end
end
