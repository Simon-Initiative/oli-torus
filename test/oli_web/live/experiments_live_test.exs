defmodule OliWeb.ExperimentsLiveTest do
  use ExUnit.Case, async: true
  alias Oli.Authoring.Experiments
  alias Oli.Resources.Revision
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  defp live_view_experiments_route(project_slug) do
    ~p"/authoring/project/#{project_slug}/experiments"
  end

  defp put_view(context) do
    {:ok, view, _html} = live(context.conn, live_view_experiments_route(context.project.slug))
    [view: view]
  end

  defp create_project(_conn) do
    project = insert(:project)
    container_resource = insert(:resource)

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      })

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision
    })

    [project: project]
  end

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the experiments view", %{
      conn: conn
    } do
      project = insert(:project)

      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_experiments_route(project.slug))
    end
  end

  describe "user cannot access when is logged in as a student" do
    setup [:user_conn, :create_project]

    test "redirects to new session when accessing the experiments view", %{
      conn: conn,
      project: project
    } do
      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_experiments_route(project.slug))
    end
  end

  describe "user cannot access when is logged in as an instructor" do
    setup [:instructor_conn, :create_project]

    test "redirects to new session when accessing the experiments view", %{
      conn: conn,
      project: project
    } do
      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_experiments_route(project.slug))
    end
  end

  describe "experiments view" do
    setup [:admin_conn, :create_project, :put_view]

    test "loads experiments view correctly", %{view: view} do
      {view, %{}}
      |> step(:test_has_title_AB_testing)
      |> step(:test_has_message_integrate_with_AB_platform)
      |> step(:test_has_checkbox)
    end

    test "when clicked on checkbox creates and displays experiment with 2 options", %{view: view} do
      {view, %{}}
      |> step(:test_has_alternatives_group, :refute)
      |> step(:click_on_checkbox)
      |> step(:test_has_alternatives_group)
      |> step(:test_has_options)
      |> step(:put_resource_id)
      |> step(:put_options)
      |> step(:test_has_button_show_edit_group_modal)
      |> step(:test_has_button_show_edit_option_1_modal)
      |> step(:test_has_button_show_edit_option_2_modal)
      |> step(:test_has_button_show_delete_option_1_modal)
      |> step(:test_has_button_show_delete_option_2_modal)
      |> step(:test_has_new_option_link)
    end

    test "when checkbox is off then disable the ability to modify experiment", %{view: view} do
      {view, %{}}
      |> step(:click_on_checkbox)
      |> step(:put_resource_id)
      |> step(:put_options)
      |> step(:click_on_checkbox)
      |> step(:test_has_button_show_edit_group_modal, :refute)
      |> step(:test_has_button_show_edit_option_1_modal, :refute)
      |> step(:test_has_button_show_edit_option_2_modal, :refute)
      |> step(:test_has_button_show_delete_option_1_modal, :refute)
      |> step(:test_has_button_show_delete_option_2_modal, :refute)
      |> step(:test_has_new_option_link, :refute)
    end

    test "no new alternative resource is created if it already exists", %{
      view: view,
      conn: conn,
      project: project
    } do
      {_old_view, context} =
        {view, %{}}
        |> step(:click_on_checkbox)
        |> step(:put_resource_id)
        |> step(:put_options)

      # Reloads page
      {:ok, view, _html} = live(conn, live_view_experiments_route(project.slug))

      {view, context}
      |> step(:click_on_checkbox)
      |> step(:test_has_alternatives_group)
      |> step(:test_has_options)
      |> step(:test_has_button_show_edit_group_modal, :refute)
      |> step(:test_has_button_show_edit_option_1_modal, :refute)
      |> step(:test_has_button_show_edit_option_2_modal, :refute)
      |> step(:test_has_button_show_delete_option_1_modal, :refute)
      |> step(:test_has_button_show_delete_option_2_modal, :refute)
      |> step(:test_has_new_option_link, :refute)
    end

    test "hide/show download buttons when checkbox is checked/unchecked", %{view: view} do
      {view, %{}}
      |> step(:test_has_button_download_segment_json, :refute)
      |> step(:test_has_button_download_experiment_json, :refute)
      |> step(:click_on_checkbox)
      |> step(:test_has_button_download_segment_json)
      |> step(:test_has_button_download_experiment_json)
    end

    test "creates new option correctly", %{view: view, project: project} do
      {view, %{project: project}}
      |> step(:click_on_checkbox)
      |> step(:put_resource_id)
      |> step(:put_options)
      |> step(:test_experiment_has_2_options)
      |> step(:test_has_new_option_link)
      |> step(:click_on_create_option_button)
      |> step(:submit_create_option_form)
      |> step(:test_experiment_has_3_options)
    end

    test "does not create duplicate option", %{view: view, project: project} do
      {view, %{project: project}}
      |> step(:click_on_checkbox)
      |> step(:put_resource_id)
      |> step(:put_options)
      |> step(:test_experiment_has_2_options)
      |> step(:test_has_new_option_link)
      |> step(:click_on_create_option_button)
      |> step(:submit_create_option_form_duplicate)
      |> step(:test_duplicate_error_message)
      |> step(:test_experiment_has_2_options)
    end
  end

  defp evaluate_assertion(to_evaluate, assert_or_refute) do
    case assert_or_refute do
      :assert -> assert to_evaluate
      :refute -> refute to_evaluate
    end
  end

  defp step(_view_and_ctx, _operation, assert_or_refute \\ :assert)

  defp step({view, ctx}, :test_has_button_download_experiment_json, assert_or_refute) do
    to_evaluate = has_element?(view, "a", "Download Experiment JSON")

    evaluate_assertion(to_evaluate, assert_or_refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_download_segment_json, assert_or_refute) do
    to_evaluate = has_element?(view, "a", "Download Segment JSON")

    evaluate_assertion(to_evaluate, assert_or_refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_has_alternatives_group, assert_or_refute) do
    to_evaluate = has_element?(view, ".alternatives-group", "Decision Point")
    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_show_edit_group_modal, assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    to_evaluate =
      has_element?(
        view,
        "button[phx-click=\"show_edit_group_modal\"][phx-value-resource-id=\"#{resource_id}\"] > .fa-pencil"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_has_checkbox, assert_or_refute) do
    to_evaluate = has_element?(view, "label", "Enable A/B testing with UpGrade")
    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_message_integrate_with_AB_platform, assert_or_refute) do
    target_text = "To support A/B testing, Torus integrates with the A/B testing platform"
    to_evaluate = element(view, "p") |> render() =~ target_text
    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_title_AB_testing, assert_or_refute) do
    to_evaluate = element(view, "h3") |> render() =~ "A/B Testing with UpGrade"
    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_options, assert_or_refute) do
    to_evaluate = has_element?(view, ".list-group", "Option 1")
    evaluate_assertion(to_evaluate, assert_or_refute)
    to_evaluate = has_element?(view, ".list-group", "Option 2")
    evaluate_assertion(to_evaluate, assert_or_refute)
    to_evaluate = has_element?(view, ".list-group", "Option 3")
    evaluate_assertion(to_evaluate, :refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_show_edit_option_1_modal, assert_or_refute) do
    option_1 = Map.get(ctx, :option_1)
    assert option_1

    to_evaluate =
      has_element?(
        view,
        "button[phx-click=\"show_edit_option_modal\"][phx-value-option-id=\"#{option_1["id"]}\"] > .fa-pencil"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)

    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_show_edit_option_2_modal, assert_or_refute) do
    option_2 = Map.get(ctx, :option_2)
    assert option_2

    to_evaluate =
      has_element?(
        view,
        "button[phx-click=\"show_edit_option_modal\"][phx-value-option-id=\"#{option_2["id"]}\"] > .fa-pencil"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_show_delete_option_1_modal, assert_or_refute) do
    option_1 = Map.get(ctx, :option_1)
    assert option_1

    to_evaluate =
      has_element?(
        view,
        "button[phx-click=\"show_delete_option_modal\"][phx-value-option-id=\"#{option_1["id"]}\"] > .fa-trash"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_button_show_delete_option_2_modal, assert_or_refute) do
    option_2 = Map.get(ctx, :option_2)
    assert option_2

    to_evaluate =
      has_element?(
        view,
        "button[phx-click=\"show_delete_option_modal\"][phx-value-option-id=\"#{option_2["id"]}\"] > .fa-trash"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)
    {view, ctx}
  end

  defp step({view, ctx}, :test_has_new_option_link, assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    to_evaluate =
      has_element?(
        view,
        "button[phx-click=\"show_create_option_modal\"][phx-value-resource_id=\"#{resource_id}\"]"
      )

    evaluate_assertion(to_evaluate, assert_or_refute)

    {view, ctx}
  end

  defp step({view, ctx}, :click_on_checkbox, _assert_or_refute) do
    view |> element("input[phx-click=\"enable_upgrade\"]") |> render_click()
    {view, ctx}
  end

  defp step({view, ctx}, :click_on_create_option_button, _assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    view
    |> element(
      "button[phx-click=\"show_create_option_modal\"][phx-value-resource_id=\"#{resource_id}\"]"
    )
    |> render_click()

    {view, ctx}
  end

  defp step({view, ctx}, :submit_create_option_form, _assert_or_refute) do
    view
    |> form("#create_modal > div > div > form", %{"params" => %{"name" => "Option 3"}})
    |> render_submit()

    {view, ctx}
  end

  defp step({view, ctx}, :submit_create_option_form_duplicate, _assert_or_refute) do
    view
    |> form("#create_modal > div > div > form", %{"params" => %{"name" => "Option 1"}})
    |> render_submit()

    {view, ctx}
  end

  defp step({view, ctx}, :test_experiment_has_2_options, _assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    content = Experiments.get_latest_experiment(ctx.project.slug).content
    option_names = get_in(content, ["options", Access.all(), "name"])
    assert option_names == ["Option 1", "Option 2"]

    {view, ctx}
  end

  defp step({view, ctx}, :test_experiment_has_3_options, _assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    content = Experiments.get_latest_experiment(ctx.project.slug).content
    option_names = get_in(content, ["options", Access.all(), "name"])
    assert option_names == ["Option 3", "Option 1", "Option 2"]

    {view, ctx}
  end

  defp step({view, ctx}, :test_duplicate_error_message, _assert_or_refute) do
    assert render(view) =~
             "The option could not be created because duplicate options have been found"

    {view, ctx}
  end

  defp step({view, ctx}, :put_options, _assert_or_refute) do
    resource_id = Map.get(ctx, :resource_id)
    assert resource_id

    [option_1, option_2] =
      Oli.Repo.get_by!(Revision, resource_id: resource_id).content["options"]

    ctx = ctx |> Map.put(:option_1, option_1) |> Map.put(:option_2, option_2)
    {view, ctx}
  end

  defp step({view, ctx}, :put_resource_id, _assert_or_refute) do
    [resource_id] =
      view
      |> element("button[phx-click=\"show_edit_group_modal\"]")
      |> render()
      |> Floki.parse_document!()
      |> Floki.find("button[phx-click=\"show_edit_group_modal\"]")
      |> Floki.attribute("phx-value-resource-id")

    {view, Map.put(ctx, :resource_id, resource_id)}
  end
end
