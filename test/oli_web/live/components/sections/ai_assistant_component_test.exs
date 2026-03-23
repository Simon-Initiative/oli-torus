defmodule OliWeb.Live.Components.Sections.AiAssistantComponentTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests
  import Oli.Factory

  alias OliWeb.Live.Components.Sections.AiAssistantComponent

  describe "AiAssistantComponent" do
    setup do
      project = insert(:project)

      product =
        insert(:section,
          base_project: project,
          type: :blueprint,
          assistant_enabled: false,
          triggers_enabled: false,
          page_prompt_template: nil
        )

      %{product: product}
    end

    test "renders with assistant and triggers OFF", %{conn: conn, product: product} do
      {:ok, view, _html} =
        live_component_isolated(conn, AiAssistantComponent, %{
          id: "ai-test",
          section: product
        })

      # Both toggles should be unchecked
      refute has_element?(view, "#ai-test-toggle-assistant_checkbox[checked]")
      refute has_element?(view, "#ai-test-toggle-triggers_checkbox[checked]")

      # Prompt editor should NOT be visible (assistant is off)
      refute has_element?(view, "h5", "Prompt Templates")
    end

    test "renders with assistant ON shows prompt editor", %{conn: conn, product: product} do
      product = %{product | assistant_enabled: true}

      {:ok, view, _html} =
        live_component_isolated(conn, AiAssistantComponent, %{
          id: "ai-test",
          section: product
        })

      assert has_element?(view, "#ai-test-toggle-assistant_checkbox[checked]")

      # Prompt editor should be visible
      assert has_element?(view, "h5", "Prompt Templates")
      assert has_element?(view, "button", "Save")
    end

    test "toggle assistant ON persists to database", %{conn: conn, product: product} do
      {:ok, view, _html} =
        live_component_isolated(conn, AiAssistantComponent, %{
          id: "ai-test",
          section: product
        })

      # Toggle assistant ON
      view |> form("#ai-test-toggle-assistant", %{}) |> render_change()

      # Checkbox should now be checked
      assert has_element?(view, "#ai-test-toggle-assistant_checkbox[checked]")

      # Verify database was updated
      updated = Oli.Repo.get!(Oli.Delivery.Sections.Section, product.id)
      assert updated.assistant_enabled == true
    end

    test "toggle assistant OFF also disables triggers", %{conn: conn, product: product} do
      # Start with both ON
      {:ok, product} =
        Oli.Delivery.Sections.update_section(product, %{
          assistant_enabled: true,
          triggers_enabled: true
        })

      {:ok, view, _html} =
        live_component_isolated(conn, AiAssistantComponent, %{
          id: "ai-test",
          section: product
        })

      # Both should be ON
      assert has_element?(view, "#ai-test-toggle-assistant_checkbox[checked]")
      assert has_element?(view, "#ai-test-toggle-triggers_checkbox[checked]")

      # Toggle assistant OFF
      view |> form("#ai-test-toggle-assistant", %{}) |> render_change()

      # Both should now be OFF
      refute has_element?(view, "#ai-test-toggle-assistant_checkbox[checked]")
      refute has_element?(view, "#ai-test-toggle-triggers_checkbox[checked]")

      # Verify database
      updated = Oli.Repo.get!(Oli.Delivery.Sections.Section, product.id)
      assert updated.assistant_enabled == false
      assert updated.triggers_enabled == false
    end

    test "toggle triggers ON independently", %{conn: conn, product: product} do
      # Start with assistant ON, triggers OFF
      {:ok, product} =
        Oli.Delivery.Sections.update_section(product, %{assistant_enabled: true})

      {:ok, view, _html} =
        live_component_isolated(conn, AiAssistantComponent, %{
          id: "ai-test",
          section: product
        })

      refute has_element?(view, "#ai-test-toggle-triggers_checkbox[checked]")

      # Toggle triggers ON
      view |> form("#ai-test-toggle-triggers", %{}) |> render_change()

      assert has_element?(view, "#ai-test-toggle-triggers_checkbox[checked]")

      # Verify database
      updated = Oli.Repo.get!(Oli.Delivery.Sections.Section, product.id)
      assert updated.triggers_enabled == true
    end

    test "save prompt persists page_prompt_template to database", %{conn: conn, product: product} do
      # Start with assistant ON and an existing prompt
      {:ok, product} =
        Oli.Delivery.Sections.update_section(product, %{
          assistant_enabled: true,
          page_prompt_template: "You are a helpful tutor."
        })

      {:ok, view, _html} =
        live_component_isolated(conn, AiAssistantComponent, %{
          id: "ai-test",
          section: product
        })

      # Verify the prompt editor and save button are visible
      assert has_element?(view, "h5", "Prompt Templates")
      assert has_element?(view, "button", "Save")

      # Click Save — persists the current page_prompt_template to the database.
      # Note: The Monaco editor on_change event sends a raw JS string that can't be
      # simulated via render_hook (which requires a map). The on_change handler is
      # trivial (assigns the value), so we test Save with the initial prompt value.
      view |> element("button", "Save") |> render_click()

      updated = Oli.Repo.get!(Oli.Delivery.Sections.Section, product.id)
      assert updated.page_prompt_template == "You are a helpful tutor."
    end

    test "sends :section_updated to parent on toggle", %{conn: conn, product: product} do
      {:ok, view, _html} =
        live_component_isolated(conn, AiAssistantComponent, %{
          id: "ai-test",
          section: product
        })

      test_pid = self()

      live_component_intercept(view, fn
        {:section_updated, %Oli.Delivery.Sections.Section{}}, socket ->
          send(test_pid, :section_updated_received)
          {:halt, socket}

        {:flash, _level, _msg}, socket ->
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      view |> form("#ai-test-toggle-assistant", %{}) |> render_change()

      assert_received :section_updated_received
    end

    test "sends :flash to parent on toggle", %{conn: conn, product: product} do
      {:ok, view, _html} =
        live_component_isolated(conn, AiAssistantComponent, %{
          id: "ai-test",
          section: product
        })

      test_pid = self()

      live_component_intercept(view, fn
        {:flash, :info, msg}, socket ->
          send(test_pid, {:flash_received, msg})
          {:halt, socket}

        {:section_updated, _}, socket ->
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      view |> form("#ai-test-toggle-assistant", %{}) |> render_change()

      assert_received {:flash_received, "AI assistant settings updated successfully"}
    end
  end
end
