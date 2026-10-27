defmodule OliWeb.LtiExternalTool.RemixLiveTest do
  @moduledoc "Verifies the Add Materials picker retains the chosen template through saving."

  use OliWeb.ConnCase

  import Oli.Scenarios.LtiExternalTool.DeepLinkingHelpers

  import Phoenix.LiveViewTest

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Scenarios.LtiExternalTool.DeepLinkingHooks, as: Hooks

  test "template selection survives unchecking/rechecking in Add Materials and saving", %{
    conn: conn
  } do
    state = execute_scenario(Path.join(__DIR__, "remix_setup.scenario.yaml"))
    source = state.products["template"]
    destination = state.sections["destination_course"]
    user = state.users["remix_instructor"]
    id = Hooks.activity(state).resource_id

    assert {:ok, _} =
             Sections.enroll(user.id, destination.id, [ContextRoles.get_role(:context_instructor)])

    assert {:ok, _} =
             PlatformExternalTools.upsert_section_resource_deep_link(%{
               section_id: source.id,
               resource_id: id,
               type: :ltiResourceLink,
               url: "https://tool.example/template-local",
               custom: %{"mode" => "template-local"}
             })

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil, section_slug: destination.slug)
      |> log_in_user(user)

    assert {:ok, view, _} = live(conn, ~p"/sections/#{destination.slug}/remix")
    view |> element("button[phx-click='show_add_materials_modal']") |> render_click()
    render_hook(view, "HierarchyPicker.select_publication", %{"key" => "product:#{source.id}"})

    for _ <- 1..3 do
      view
      |> element(".hierarchy > div[id^=\"hierarchy_item_\"]", "Tool Lesson")
      |> render_click()
    end

    view |> element("button[phx-click='AddMaterialsModal.add']", "Add") |> render_click()
    assert view |> element("#save") |> render_click() =~ "Your work has been saved."

    copied =
      PlatformExternalTools.get_section_resource_deep_link_by(
        section_id: destination.id,
        resource_id: id
      )

    assert copied.custom == %{"mode" => "template-local"}
  end
end
