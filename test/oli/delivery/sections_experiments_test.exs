defmodule Oli.Delivery.SectionsExperimentsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections

  alias Oli.Experiments.Schemas.{
    ExperimentDefinition,
    ExperimentSection
  }

  test "has_experiment?/1 uses section participation as its source of truth" do
    project = insert(:project)
    participating_section = insert(:section, base_project: project)
    ordinary_section = insert(:section, base_project: project)

    experiment =
      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: project.id,
        slug: "section-experiment-guard",
        name: "Section experiment guard",
        algorithm: :weighted_random
      })
      |> Repo.insert!()

    %ExperimentSection{}
    |> ExperimentSection.changeset(%{
      experiment_id: experiment.id,
      section_id: participating_section.id
    })
    |> Repo.insert!()

    assert Sections.has_experiment?(participating_section.id)
    refute Sections.has_experiment?(ordinary_section.id)
    refute Sections.has_experiment?(nil)
  end
end
