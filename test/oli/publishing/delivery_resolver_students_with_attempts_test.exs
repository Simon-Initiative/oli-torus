defmodule Oli.Publishing.DeliveryResolverStudentsWithAttemptsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  test "uses the delivery analytics scope for v2 sections" do
    section = insert(:section, analytics_version: :v2)
    page = insert(:resource)
    page_type_id = ResourceType.id_for_page()

    Repo.insert_all("resource_summary", [
      summary_row(-1, section.id, 101, page.id, page_type_id),
      summary_row(42, section.id, 202, page.id, page_type_id)
    ])

    assert DeliveryResolver.students_with_attempts_for_page(
             %{resource_id: page.id},
             section,
             [101, 202]
           ) == [101]
  end

  defp summary_row(project_id, section_id, user_id, resource_id, resource_type_id) do
    %{
      project_id: project_id,
      section_id: section_id,
      user_id: user_id,
      resource_id: resource_id,
      resource_type_id: resource_type_id,
      part_id: nil,
      num_correct: 1,
      num_attempts: 1,
      num_hints: 0,
      num_first_attempts: 1,
      num_first_attempts_correct: 1
    }
  end
end
