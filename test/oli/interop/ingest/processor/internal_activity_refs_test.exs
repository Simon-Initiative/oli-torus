defmodule Oli.Interop.Ingest.Processor.InternalActivityRefsTest do
  use Oli.DataCase

  alias Oli.Activities
  alias Oli.Interop.Ingest.Processor.InternalActivityRefs
  alias Oli.Interop.Ingest.State
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Seeder

  describe "process/1" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "rewires activities required for evaluation through the legacy resource map", %{
      author: author,
      project: project,
      publication: publication
    } do
      required_activity =
        Seeder.create_activity(
          %{
            title: "Select a Warming Limit",
            activity_type_id: Activities.get_registration_by_slug("oli_adaptive").id
          },
          publication,
          project,
          author
        ).revision

      string_required_activity =
        Seeder.create_activity(
          %{
            title: "Select Planet Type",
            activity_type_id: Activities.get_registration_by_slug("oli_adaptive").id
          },
          publication,
          project,
          author
        ).revision

      dependent_activity =
        Seeder.create_activity(
          %{
            title: "Is Your Target Possible?",
            activity_type_id: Activities.get_registration_by_slug("oli_adaptive").id,
            content: %{
              "authoring" => %{
                "activitiesRequiredForEvaluation" => [715_804, "715806"],
                "flowchart" => %{
                  "paths" => [%{"id" => "next", "destinationScreenId" => "715806"}]
                }
              }
            }
          },
          publication,
          project,
          author
        ).revision

      state = %State{
        project: project,
        legacy_to_resource_id_map: %{
          "715804" => required_activity.resource_id,
          "715805" => dependent_activity.resource_id,
          "715806" => string_required_activity.resource_id
        }
      }

      InternalActivityRefs.process(state)

      updated_dependent_activity =
        AuthoringResolver.from_resource_id(project.slug, dependent_activity.resource_id)

      assert get_in(updated_dependent_activity.content, [
               "authoring",
               "activitiesRequiredForEvaluation"
             ]) == [required_activity.resource_id, string_required_activity.resource_id]

      assert get_in(updated_dependent_activity.content, [
               "authoring",
               "flowchart",
               "paths",
               Access.at(0),
               "destinationScreenId"
             ]) == string_required_activity.resource_id
    end
  end
end
