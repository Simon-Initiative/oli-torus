defmodule OliWeb.GenAI.FeatureConfigsViewTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}
  alias Oli.GenAI.FeatureConfig
  alias OliWeb.GenAI.FeatureConfigsView
  alias Oli.Repo

  @route Routes.live_path(OliWeb.Endpoint, FeatureConfigsView)

  describe "feature_options/0" do
    test "covers every feature in the FeatureConfig whitelist" do
      option_values = FeatureConfigsView.feature_options() |> Enum.map(fn {_label, v} -> v end)

      # Guards the MER-5257 drift: the dropdowns must always reflect the
      # whitelist, so a newly supported feature can never be silently
      # unselectable again.
      assert Enum.sort(option_values) == Enum.sort(FeatureConfig.features())
    end

    test "includes :instructor_email with a human-readable label" do
      assert {"Instructor Email", :instructor_email} in FeatureConfigsView.feature_options()
    end

    test "humanizes multi-word feature atoms" do
      assert {"Instructor Dashboard Recommendation", :instructor_dashboard_recommendation} in FeatureConfigsView.feature_options()
    end
  end

  describe "rendered admin page" do
    setup [:admin_conn, :create_feature_config]

    test "Create and Edit feature dropdowns expose instructor_email", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route)

      # The actual changed UI surfaces, not just the helper: both dropdowns
      # render the option, proving the templates consume feature_options/0.
      assert html =~ ~s(value="instructor_email")
      assert html =~ "Instructor Email"
    end

    test "selecting instructor_email in the Create form does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, @route)

      html =
        view
        |> element("form[phx-change=\"feature_changed\"]")
        |> render_change(%{"feature" => "instructor_email"})

      assert html =~ ~s(value="instructor_email")
    end
  end

  defp create_feature_config(_context) do
    model =
      Repo.insert!(%RegisteredModel{
        name: "Test Model",
        provider: :null,
        model: "null",
        url_template: "http://localhost",
        api_key: "secret",
        timeout: 8000,
        recv_timeout: 60_000
      })

    service_config = Repo.insert!(%ServiceConfig{name: "standard", primary_model_id: model.id})

    feature_config =
      Repo.insert!(%FeatureConfig{
        feature: :student_dialogue,
        service_config_id: service_config.id,
        section_id: nil
      })

    {:ok, service_config: service_config, feature_config: feature_config}
  end
end
