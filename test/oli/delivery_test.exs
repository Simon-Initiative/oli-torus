defmodule Oli.DeliveryTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery
  alias Oli.Delivery.DeliverySetting
  alias Oli.Resources.Collaboration.CollabSpaceConfig

  describe "delivery settings" do
    test "create_delivery_setting/1 with valid data creates a delivery_setting" do
      params = params_with_assocs(:delivery_setting)
      assert {:ok, %DeliverySetting{} = delivery_setting} =
        Delivery.create_delivery_setting(params)

      assert delivery_setting.collab_space_config.status == params.collab_space_config.status
      assert delivery_setting.collab_space_config.threaded == params.collab_space_config.threaded
      assert delivery_setting.user_id == params.user_id
      assert delivery_setting.section_id == params.section_id
      assert delivery_setting.resource_id == params.resource_id
    end

    test "get_delivery_setting_by/1 returns a delivery_setting when the id exists" do
      delivery_setting = insert(:delivery_setting)

      returned_delivery_setting = Delivery.get_delivery_setting_by(%{id: delivery_setting.id})

      assert delivery_setting.id == returned_delivery_setting.id
      assert delivery_setting.section_id == returned_delivery_setting.section_id
    end

    test "get_delivery_setting_by/1 returns nil if the delivery_setting does not exist" do
      assert nil == Delivery.get_delivery_setting_by(%{id: -1})
    end

    test "update_delivery_setting/2 updates the delivery_setting successfully" do
      delivery_setting = insert(:delivery_setting)
      new_attrs = params_for(:collab_space_config, status: :archived)

      {:ok, updated_delivery_setting} =
        Delivery.update_delivery_setting(delivery_setting, %{collab_space_config: new_attrs})

      assert delivery_setting.id == updated_delivery_setting.id
      assert updated_delivery_setting.collab_space_config.status == :archived
    end

    test "change_delivery_setting/1 returns a delivery_setting changeset" do
      delivery_setting = insert(:delivery_setting)
      assert %Ecto.Changeset{} = Delivery.change_delivery_setting(delivery_setting)
    end

    test "search_delivery_settings/1 returns all delivery_settings meeting the criteria" do
      section = insert(:section)
      other_section = insert(:section)
      [delivery_setting | _] = insert_pair(:delivery_setting, section: section)
      insert(:delivery_setting, section: other_section)

      assert [returned_delivery_setting | _] = Delivery.search_delivery_settings(%{section_id: section.id})

      assert returned_delivery_setting.id == delivery_setting.id
      assert returned_delivery_setting.collab_space_config == %CollabSpaceConfig{}
    end

    test "search_delivery_settings/1 returns empty when no delivery_setting meets the criteria" do
      insert_pair(:delivery_setting)

      assert [] == Delivery.search_delivery_settings(%{section_id: -1})
    end

    test "upsert_delivery_setting/1 with valid data creates a delivery_setting" do
      params = params_with_assocs(:delivery_setting)
      assert {:ok, %DeliverySetting{} = delivery_setting} =
        Delivery.upsert_delivery_setting(params)

      assert delivery_setting.collab_space_config.status == params.collab_space_config.status
      assert delivery_setting.collab_space_config.threaded == params.collab_space_config.threaded
      assert delivery_setting.user_id == params.user_id
      assert delivery_setting.section_id == params.section_id
      assert delivery_setting.resource_id == params.resource_id
    end

    test "upsert_delivery_setting/2 updates the delivery_setting successfully" do
      delivery_setting = insert(:delivery_setting)
      new_attrs = params_for(:collab_space_config, status: :archived)

      {:ok, updated_delivery_setting} =
        Delivery.upsert_delivery_setting(Map.merge(Map.from_struct(delivery_setting), %{collab_space_config: new_attrs}))

      assert delivery_setting.id == updated_delivery_setting.id
      assert updated_delivery_setting.collab_space_config.status == :archived
    end

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
