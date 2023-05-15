defmodule Oli.DeliveryTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery
  alias Oli.Resources.Collaboration.CollabSpaceConfig

  describe "delivery settings" do
    test "maybe_update_section_contains_explorations/1 update contains_explorations field" do
      {:ok,
       project: _project,
       section: section,
       page_revision: _page_revision,
       other_revision: other_revision} = project_section_revisions(%{})

      author = insert(:author)

      assert section.contains_explorations

      Oli.Resources.update_revision(other_revision, %{purpose: :foundation, author_id: author.id})

      Delivery.maybe_update_section_contains_explorations(section)
      section_without_explorations = Oli.Delivery.Sections.get_section_by_slug(section.slug)

      refute section_without_explorations.contains_explorations
    end
  end
end
