defmodule OliWeb.Curriculum.OptionsModalContentTest do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import LiveComponentTests
  import Oli.Factory
  import Mox

  alias Oli.Resources.ResourceType

  defp build_project() do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "revision A"
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "revision B",
        poster_image: "https://your_s3_media_bucket_url.s3.amazonaws.com/b.jpg"
      )

    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [page_revision.resource_id, page_2_revision.resource_id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    all_revisions =
      [
        page_revision,
        page_2_revision,
        container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource_id,
        published: nil
      })

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    project_hierarchy =
      project.slug
      |> Oli.Publishing.AuthoringResolver.full_hierarchy()
      |> Oli.Delivery.Hierarchy.HierarchyNode.simplify()

    [
      project: project,
      publication: publication,
      page_revision: page_revision,
      page_2_revision: page_2_revision,
      author: author,
      container_revision: container_revision,
      project_hierarchy: project_hierarchy
    ]
  end

  describe "live component" do
    setup do
      build_project()
    end

    test "renders default image if revision has no poster_image", %{
      conn: conn,
      project: project,
      page_revision: revision,
      project_hierarchy: project_hierarchy
    } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      assert has_element?(lcd, "img[src='/images/course_default.jpg']")
    end

    test "renders poster image if the page revision has one", %{
      conn: conn,
      project: project,
      page_2_revision: page_2_revision,
      project_hierarchy: project_hierarchy
    } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: page_2_revision,
          changeset: Oli.Resources.change_revision(page_2_revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      assert has_element?(
               lcd,
               "img[data-filename='b.jpg']"
             )
    end

    test "lists previous uploaded images in the poster image selection step", %{
      conn: conn,
      project: project,
      page_revision: revision,
      project_hierarchy: project_hierarchy
    } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: %{contents: [%{key: "a.jpg"}, %{key: "b.jpg"}]}}}
      end)

      # go to image selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=poster_image]", "Select")
      |> render_click()

      assert has_element?(
               lcd,
               "button[data-filename='a.jpg']"
             )

      assert has_element?(
               lcd,
               "button[data-filename='b.jpg']"
             )
    end

    test "current selected image is listed first and styled with a blue outline when rendering the image selection step",
         %{
           conn: conn,
           project: project,
           page_2_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok,
         %{
           status_code: 200,
           body: %{contents: [%{key: "a.jpg"}, %{key: "b.jpg"}, %{key: "c.jpg"}]}
         }}
      end)

      # go to image selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=poster_image]", "Select")
      |> render_click()

      first_image = element(lcd, "button[phx-click=select-resource]:first-of-type img")

      assert render(first_image)
             |> Floki.attribute("src")
             |> hd() =~
               "b.jpg"

      assert render(first_image)
             |> Floki.attribute("class")
             |> hd() =~ "!outline-[7px] outline-blue-400"
    end

    test "upload text adapts considering if there are no previous uploaded images", %{
      conn: conn,
      project: project,
      page_revision: revision,
      project_hierarchy: project_hierarchy
    } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: %{contents: []}}}
      end)

      # go to image selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=poster_image]", "Select")
      |> render_click()

      assert has_element?(lcd, "a", "Upload a poster image")

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: %{contents: [%{key: "a.jpg"}]}}}
      end)

      # go to image selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=poster_image]", "Select")
      |> render_click()

      assert has_element?(lcd, "a", "upload a new one")
    end

    test "can upload an image to S3 and select is as poster image", %{
      conn: conn,
      project: project,
      page_revision: revision,
      project_hierarchy: project_hierarchy
    } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      # this mock is for the 2 images previously uploaded
      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: %{contents: [%{key: "a.jpg"}, %{key: "b.jpg"}]}}}
      end)

      assert element(lcd, "img[role=`poster_image`]")
             |> render()
             |> Floki.attribute("src")
             |> hd() =~
               "/images/course_default.jpg"

      # go to image selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=poster_image]", "Select")
      |> render_click()

      refute has_element?(lcd, "img[phx-value-url='uploaded_one']")

      # this mock is for the image that will be uploaded
      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200}}
      end)

      # upload an image
      path = "assets/static/images/course_default.jpg"

      image =
        file_input(lcd, "#upload-form", :poster_image, [
          %{
            last_modified: 1_594_171_879_000,
            name: "myfile.jpeg",
            content: File.read!(path),
            type: "image/jpeg"
          }
        ])

      render_upload(image, "myfile.jpeg")

      # can see the uploaded image
      assert has_element?(lcd, "img[phx-value-url='uploaded_one']")

      # save changes and go back to general step (the uploaded image should be displayed)
      lcd
      |> element("#upload-form")
      |> render_submit(%{})

      lcd
      |> element("button[phx-click=change_step]", "Select")
      |> render_click()

      refute element(lcd, "img[role=`poster_image`]")
             |> render()
             |> Floki.attribute("src")
             |> hd() =~
               "/images/course_default.jpg"
    end

    test "can Cancel image selection after upload has been completed, go back to the first modal step, and the initial poster image should not have changed",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok,
         %{
           status_code: 200,
           body: %{contents: [%{key: "a.jpg"}, %{key: "b.jpg"}, %{key: "c.jpg"}]}
         }}
      end)

      # go to image selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=poster_image]", "Select")
      |> render_click()

      # upload an image
      path = "assets/static/images/course_default.jpg"

      image =
        file_input(lcd, "#upload-form", :poster_image, [
          %{
            last_modified: 1_594_171_879_000,
            name: "myfile.jpeg",
            content: File.read!(path),
            type: "image/jpeg"
          }
        ])

      render_upload(image, "myfile.jpeg")

      # cancel and go back to general step
      lcd
      |> element("button[phx-click=change_step]", "Cancel")
      |> render_click()

      assert has_element?(
               lcd,
               "img[src='/images/course_default.jpg']"
             )
    end

    test "can select a previously uploaded image (and see it in the general step after clicking on 'Select')",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok,
         %{
           status_code: 200,
           body: %{contents: [%{key: "a.jpg"}, %{key: "b.jpg"}, %{key: "c.jpg"}]}
         }}
      end)

      refute has_element?(
               lcd,
               "button[data-filename='c.jpg']"
             )

      # go to image selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=poster_image]", "Select")
      |> render_click()

      not_yet_selected_image =
        element(lcd, "button[data-filename='c.jpg'] img")

      refute render(not_yet_selected_image)
             |> Floki.attribute("class")
             |> hd() =~ "!outline-[7px] outline-blue-400"

      # select an image from the list (it should be styled as the selected one)
      lcd
      |> element("button[data-filename='c.jpg']")
      |> render_click()

      selected_image =
        element(lcd, "button[data-filename='c.jpg'] img")

      assert render(selected_image)
             |> Floki.attribute("class")
             |> hd() =~ "!outline-[7px] outline-blue-400"

      # go back to general step (the selected image should be displayed)
      lcd
      |> element("button[phx-click=change_step]", "Select")
      |> render_click()

      assert has_element?(
               lcd,
               "img[data-filename='c.jpg']"
             )
    end

    test "a `save-options` event with the selected poster image data is sent to the parent liveview after an image is selected/uploaded and the general form is submitted",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      test_pid = self()

      # Intercepts `handle_event` from the LiveView that holds the LiveComponent.
      live_component_event_intercept(lcd, fn
        "save-options" = event, params, socket ->
          send(test_pid, {:handle_event_intercepted, event, params})
          {:halt, socket}

        _, _params, socket ->
          {:cont, socket}
      end)

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: %{contents: [%{key: "a.jpg"}, %{key: "b.jpg"}]}}}
      end)

      # go to image selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=poster_image]", "Select")
      |> render_click()

      # select "b.jpg" image from the list
      lcd
      |> element("button[data-filename='b.jpg']")
      |> render_click()

      # go back to general step
      lcd
      |> element("button[phx-click=change_step]", "Select")
      |> render_click()

      # submit the form
      lcd
      |> element("form[id=revision-settings-form]")
      |> render_submit()

      # the `save-options` event should be sent to the parent liveview with the selected image
      assert_received {:handle_event_intercepted, "save-options",
                       %{
                         "revision" => %{
                           "poster_image" => url
                         }
                       }}

      assert url =~ "b.jpg"
    end

    test "a `restart_options_modal` event is sent to the parent liveview if the modal is closed by clicking `Cancel`",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      test_pid = self()

      # Intercepts `handle_event` from the LiveView that holds the LiveComponent.
      live_component_event_intercept(lcd, fn
        "restart_options_modal" = event, params, socket ->
          send(test_pid, {:handle_event_intercepted, event, params})
          {:halt, socket}

        _, _params, socket ->
          {:cont, socket}
      end)

      # close the modal
      lcd
      |> element("button[phx-click=restart_options_modal]", "Cancel")
      |> render_click()

      # the `restart_options_modal` event should be sent to the parent liveview
      assert_received {:handle_event_intercepted, "restart_options_modal", %{}}
    end

    test "a `save-options` event with all the form data is sent to the parent liveview when the form is submitted",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          changeset: Oli.Resources.change_revision(revision),
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal"
        })

      test_pid = self()

      # Intercepts `handle_event` from the LiveView that holds the LiveComponent.
      live_component_event_intercept(lcd, fn
        "save-options" = event, params, socket ->
          send(test_pid, {:handle_event_intercepted, event, params})
          {:halt, socket}

        _, _params, socket ->
          {:cont, socket}
      end)

      # submit the form
      lcd
      |> element("form[id=revision-settings-form]")
      |> render_submit(%{revision: %{duration_minutes: 20}})

      # the `save-options` event should be sent to the parent liveview with all the form data
      assert_received {:handle_event_intercepted, "save-options",
                       %{
                         "revision" => %{
                           "poster_image" => "/images/course_default.jpg",
                           "title" => "revision A",
                           "duration_minutes" => "20",
                           "explanation_strategy" => %{"type" => "none"},
                           "graded" => "false",
                           "purpose" => "foundation"
                         }
                       }}
    end
  end
end
