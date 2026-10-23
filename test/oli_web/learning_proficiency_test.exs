defmodule OliWeb.LearningProficiencyTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Repo

  @moduletag capture_log: true

  setup do
    seed = Oli.Seeder.base_project_with_resource2()

    project =
      seed.project
      |> Project.trusted_learning_model_changeset(%{learning_model_version: :naive})
      |> Repo.update!()

    {:ok, %{seed | project: project}}
  end

  test "overview requires exact confirmation and persists a one-way upgrade", s do
    conn = log_in_author(s.conn, s.author)
    {:ok, view, _} = live(conn, path(s.project))
    assert has_element?(view, "#learning-proficiency-settings", "Learning Proficiency")
    assert has_element?(view, "#learning-proficiency-settings", "v0.1.0")

    assert has_element?(
             view,
             "#learning-proficiency-settings",
             "Learn more about how learning proficiency is calculated in course sections made from this project and its templates."
           )

    view |> element("#upgrade-learning-framework") |> render_click()

    assert has_element?(
             view,
             "#framework-upgrade-modal",
             "Confirm Update to Learning Proficiency Framework"
           )

    assert has_element?(
             view,
             "#framework-upgrade-modal",
             "Existing learner proficiency data will not be recalculated."
           )

    assert has_element?(view, "#confirm-framework-upgrade[disabled]")

    assert has_element?(
             view,
             "#framework-upgrade-modal",
             "will update this project and all its existing templates."
           )

    assert has_element?(
             view,
             "#framework-upgrade-modal",
             "Newly created course sections from this project or its templates will use the new framework."
           )

    assert has_element?(
             view,
             "#framework-upgrade-modal",
             "Existing course sections will keep their current framework."
           )

    for invalid <- ["", "update framework", "Update Framework "] do
      view |> form("#framework-upgrade-form", confirmation: invalid) |> render_change()
      assert has_element?(view, "#confirm-framework-upgrade[disabled]")
      render_submit(view, "upgrade_framework", %{"confirmation" => invalid})
      assert Repo.get!(Project, s.project.id).learning_model_version == :naive
    end

    view |> form("#framework-upgrade-form", confirmation: "Update Framework") |> render_change()
    assert has_element?(view, "#confirm-framework-upgrade:not([disabled])")
    view |> form("#framework-upgrade-form", confirmation: "Update Framework") |> render_submit()
    assert Repo.get!(Project, s.project.id).learning_model_version == :lkt_aoa
    refute has_element?(view, "#framework-upgrade-modal")
    assert has_element?(view, "#upgrade-learning-framework[disabled]")
    assert has_element?(view, "#learning-proficiency-settings", "v0.2.0")

    {:ok, reloaded, _} = live(conn, path(s.project))
    assert has_element?(reloaded, "#upgrade-learning-framework[disabled]")
    render_click(reloaded, "show_framework_upgrade")
    refute has_element?(reloaded, "#framework-upgrade-modal")
  end

  test "cancel clears confirmation and direct submission cannot bypass the dialog", s do
    {:ok, view, _} = live(log_in_author(s.conn, s.author), path(s.project))
    render_submit(view, "upgrade_framework", %{"confirmation" => "Update Framework"})
    assert Repo.get!(Project, s.project.id).learning_model_version == :naive
    render_click(view, "show_framework_upgrade")
    view |> form("#framework-upgrade-form", confirmation: "Update Framework") |> render_change()
    render_click(view, "cancel_framework_upgrade")
    refute has_element?(view, "#framework-upgrade-modal")
    render_click(view, "show_framework_upgrade")
    assert has_element?(view, "#framework-upgrade-confirmation[value='']")
    assert has_element?(view, "#confirm-framework-upgrade[disabled]")
  end

  test "both learn more links open accessible documentation in a new tab", s do
    conn = log_in_author(s.conn, s.author)
    {:ok, view, _} = live(conn, path(s.project))
    docs = "/workspaces/course_author/#{s.project.slug}/learning_proficiency"

    assert has_element?(
             view,
             "#learning-proficiency-settings a[href='#{docs}'][target='_blank'][rel='noopener noreferrer']",
             "about learning proficiency (opens in a new tab)"
           )

    view |> element("#upgrade-learning-framework") |> render_click()

    assert has_element?(
             view,
             "#framework-upgrade-modal a[href='#{docs}'][target='_blank'][rel='noopener noreferrer']",
             "(opens in a new tab)"
           )
  end

  test "both models remain available while the current framework follows the project", s do
    conn = log_in_author(s.conn, s.author)
    docs = "/workspaces/course_author/#{s.project.slug}/learning_proficiency"

    for {model, current_id, other_id, version} <- [
          {:naive, "legacy-framework", "lkt-aoa-framework", "v0.1.0"},
          {:lkt_aoa, "lkt-aoa-framework", "legacy-framework", "v0.2.0"}
        ] do
      case model do
        :naive -> :ok
        :lkt_aoa -> assert {:ok, _} = Course.upgrade_learning_model(s.project, s.author)
      end

      {:ok, view, _} = live(conn, docs)
      assert has_element?(view, "article", version)
      assert has_element?(view, "#legacy-framework h2", "Legacy framework (v1)")
      assert has_element?(view, "#lkt-aoa-framework h2", "LKT-AOA framework (v2)")
      assert has_element?(view, "#lkt-aoa-framework h2", "Understanding confidence")

      assert has_element?(
               view,
               "##{current_id} [data-current-framework]",
               "Current framework"
             )

      refute has_element?(view, "##{other_id} [data-current-framework]")
      html = view |> render() |> Floki.parse_document!()
      assert length(Floki.find(html, "[data-current-framework]")) == 1
      assert has_element?(view, "a[href='#{path(s.project)}']", "Project Overview")
    end
  end

  test "both models offer calculation, insufficient evidence, repeat, and parent examples", s do
    docs = "/workspaces/course_author/#{s.project.slug}/learning_proficiency"
    {:ok, view, _} = live(log_in_author(s.conn, s.author), docs)

    for id <- ["legacy-proficiency-example", "lkt-aoa-proficiency-example"] do
      assert has_element?(
               view,
               "##{id} p",
               "What counts as a question: Each question is counted separately. In activities with multiple answer fields, each independently evaluated field counts separately."
             )
    end

    for {id, calculation} <- [
          {"legacy-proficiency-example", "(1 + 1 + 1 + 0.2) / 4 = 80%"},
          {"legacy-insufficient-example", "(1 + 1 + 0.2) / 3 = approximately 73.3%"},
          {"legacy-repeat-example", "(1 + 1 + 1 + 0.2) / 4 = 80%"},
          {"legacy-parent-example", "(1 + 1 + 0.2) / 3 = approximately 73.3%"},
          {"lkt-aoa-proficiency-example", "(0.4 + 0.6 + 0.8) / 3 = 60%"},
          {"lkt-aoa-insufficient-example", "(0.8 + 0.9 + 0.7) / 3 = 80%"},
          {"lkt-aoa-repeat-example", "(0.4 + 0.6 + 0.8 + 0.8) / 4 = 65%"},
          {"lkt-aoa-parent-example", "(0.8 × 4 + 0.4 × 1) / 5 = 72%"}
        ] do
      assert has_element?(view, "details##{id}:not([open]) summary", "View Example:")
      assert has_element?(view, "##{id}", calculation)
    end

    assert has_element?(
             view,
             "#legacy-insufficient-example",
             "Not enough data. Fewer than three first attempts have been made."
           )

    assert has_element?(
             view,
             "#lkt-aoa-insufficient-example",
             "Not enough data. Fewer than three attempts have been made."
           )

    assert has_element?(
             view,
             "#legacy-insufficient-example",
             "Answering either question again does not add another first attempt. The count remains two"
           )

    assert has_element?(
             view,
             "#legacy-insufficient-example",
             "A first attempt on a third different question is required to reach the minimum."
           )

    assert has_element?(
             view,
             "#lkt-aoa-insufficient-example",
             "This repetition counts toward the minimum of three attempts."
           )

    assert has_element?(
             view,
             "#lkt-aoa-insufficient-example",
             "Confidence does not increase because the learner has not attempted a different question or answer field."
           )

    assert has_element?(
             view,
             "#understanding-confidence #lkt-aoa-repeat-example summary",
             "Repeated attempts and confidence"
           )

    assert has_element?(
             view,
             "#understanding-confidence #lkt-aoa-repeat-example",
             "Increases, because the learner has now attempted a different question linked to the same sub-objective."
           )

    assert has_element?(
             view,
             "#legacy-proficiency-example",
             "(1 + 0.2 + 0.2 + 0.2) / 4 = 40%"
           )

    assert has_element?(
             view,
             "#lkt-aoa-proficiency-example",
             "At exactly 40%, this framework reports Medium"
           )

    assert has_element?(view, "#legacy-framework", "each incorrect first attempt contributes 0.2")

    assert has_element?(
             view,
             "#lkt-aoa-framework",
             "Answering the same question or answer field again contributes to proficiency but does not increase confidence."
           )
  end

  test "documentation is restricted to authorized authors and content administrators", s do
    docs = "/workspaces/course_author/#{s.project.slug}/learning_proficiency"
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().content_admin})
    assert {:ok, _, _} = live(log_in_author(s.conn, admin), docs)
    assert {:error, {:redirect, _}} = live(log_in_author(s.conn, author_fixture()), docs)
    assert {:error, {:redirect, _}} = live(log_in_user(s.conn, user_fixture()), docs)
    assert get(s.conn, docs).status == 302
  end

  test "upgrade enforces authorization and leaves existing sections and content untouched", s do
    section =
      insert(:section, base_project: s.project, type: :enrollable, learning_model_version: :naive)

    section = Repo.get!(Oli.Delivery.Sections.Section, section.id)
    revisions = Repo.all(Oli.Resources.Revision)
    assert {:error, :not_authorized} = Course.upgrade_learning_model(s.project, author_fixture())
    assert {:ok, upgraded} = Course.upgrade_learning_model(s.project, s.author)
    assert upgraded.learning_model_version == :lkt_aoa
    assert Repo.get!(Oli.Delivery.Sections.Section, section.id) == section
    assert Repo.all(Oli.Resources.Revision) == revisions
    assert {:error, :not_upgradable} = Course.upgrade_learning_model(s.project, s.author)
    assert {:ok, unchanged} = Course.update_project(upgraded, %{learning_model_version: :naive})
    assert unchanged.learning_model_version == :lkt_aoa
  end

  test "new sections inherit the upgraded framework from both project and existing templates",
       s do
    assert {:ok, template} =
             Sections.create_section_from_source(
               %{
                 title: "Legacy template",
                 type: :blueprint,
                 base_project_id: s.project.id,
                 publisher_id: s.project.publisher_id
               },
               s.project
             )

    assert {:ok, upgraded} = Course.upgrade_learning_model(s.project, s.author)
    template = Repo.reload!(template)
    assert template.learning_model_version == :lkt_aoa

    assert {:ok, new_section} =
             Sections.create_section_from_source(
               %{title: "New section", base_project_id: s.project.id},
               upgraded
             )

    assert new_section.learning_model_version == :lkt_aoa

    assert {:ok, from_template} =
             Sections.create_section_from_source(
               %{title: "From template", base_project_id: s.project.id},
               template
             )

    assert from_template.learning_model_version == :lkt_aoa
  end

  test "all project templates are upgraded in a single bulk update", s do
    templates =
      insert_list(15, :section,
        base_project: s.project,
        type: :blueprint,
        learning_model_version: :naive
      )

    other_template = insert(:section, type: :blueprint, learning_model_version: :naive)

    existing_section =
      insert(:section, base_project: s.project, type: :enrollable, learning_model_version: :naive)

    other_template = Repo.reload!(other_template)
    existing_section = Repo.reload!(existing_section)

    assert {:error, :not_authorized} = Course.upgrade_learning_model(s.project, author_fixture())
    assert Enum.all?(templates, &(Repo.reload!(&1).learning_model_version == :naive))

    handler = {__MODULE__, make_ref()}
    parent = self()

    :ok =
      :telemetry.attach(
        handler,
        [:oli, :repo, :query],
        fn _, _, metadata, _ ->
          case self() == parent and String.starts_with?(metadata.query, "UPDATE \"sections\"") do
            true -> send(parent, {handler, :template_update})
            false -> :ok
          end
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    assert {:ok, upgraded} = Course.upgrade_learning_model(s.project, s.author)
    assert upgraded.learning_model_version == :lkt_aoa
    assert_receive {^handler, :template_update}
    refute_received {^handler, :template_update}
    assert Enum.all?(templates, &(Repo.reload!(&1).learning_model_version == :lkt_aoa))
    assert Repo.get!(Section, other_template.id) == other_template
    assert Repo.get!(Section, existing_section.id) == existing_section
  end

  test "fresh creation defaults to latest while copies preserve a legacy source", s do
    attrs = Map.take(s.project, [:version, :family_id, :publisher_id]) |> Map.put(:title, "Fresh")
    assert {:ok, fresh} = Course.create_project(Map.put(attrs, :learning_model_version, :naive))
    assert fresh.learning_model_version == :lkt_aoa

    assert {:ok, copy} =
             Course.create_project_from_source(Map.put(attrs, :title, "Copy"), s.project)

    assert copy.learning_model_version == :naive
  end

  test "content administrators can upgrade projects they do not own", s do
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().content_admin})
    {:ok, view, _} = live(log_in_author(s.conn, admin), path(s.project))
    render_click(view, "show_framework_upgrade")
    view |> form("#framework-upgrade-form", confirmation: "Update Framework") |> render_submit()
    assert Repo.get!(Project, s.project.id).learning_model_version == :lkt_aoa
  end

  defp path(project), do: "/workspaces/course_author/#{project.slug}/overview"
end
