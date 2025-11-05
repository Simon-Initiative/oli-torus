defmodule OliWeb.LiveSessionPlugs.SetSectionTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias OliWeb.LiveSessionPlugs.SetSection

  describe "on_mount/4 assigns" do
    test "assigns section and nil license when project has no license" do
      section = insert(:section)

      assert {:cont, socket} =
               SetSection.on_mount(
                 :default,
                 %{"section_slug" => section.slug},
                 %{},
                 %Phoenix.LiveView.Socket{}
               )

      assert socket.assigns.section.id == section.id
      assert Map.get(socket.assigns, :license) == nil
    end

    test "assigns section and license when project has license" do
      project =
        insert(:project,
          attributes:
            build(:project_attributes,
              license: build(:project_attributes_license, license_type: :cc_by)
            )
        )

      section = insert(:section, base_project: project)

      assert {:cont, socket} =
               SetSection.on_mount(
                 :default,
                 %{"section_slug" => section.slug},
                 %{},
                 %Phoenix.LiveView.Socket{}
               )

      assert socket.assigns.section.id == section.id
      assert is_map(socket.assigns.license)
      assert Map.get(socket.assigns.license, :license_type) == :cc_by
    end

    test "halts with 404 for unknown slug" do
      base_socket = %Phoenix.LiveView.Socket{assigns: %{flash: %{}, __changed__: %{}}}

      assert {:halt, _socket} =
               SetSection.on_mount(
                 :default,
                 %{"section_slug" => "missing"},
                 %{},
                 base_socket
               )
    end
  end
end
