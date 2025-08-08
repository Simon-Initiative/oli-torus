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
        poster_image: "https://your_s3_media_bucket_url.s3.amazonaws.com/b.jpg",
        intro_video: "https://your_s3_media_bucket_url.s3.amazonaws.com/b.mp4"
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "revision C",
        poster_image: "https://your_s3_media_bucket_url.s3.amazonaws.com/c.jpg",
        # you have found an easter egg ;)
        intro_video: "https://youtu.be/i8Pq1jpM3PE"
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "revision D",
        # we repeat the same youtube link and only one should be displayed in the intro_video step
        intro_video: "https://youtu.be/i8Pq1jpM3PE"
      )

    page_5_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "revision E"
      )

    unit_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [
          page_5_revision.resource_id
        ],
        content: %{},
        title: "Unit 1",
        intro_content: %{
          "type" => "p",
          "children" => [
            %{
              "id" => "3477687079",
              "type" => "p",
              "children" => [%{"text" => "Some intro content text!"}]
            }
          ]
        }
      })

    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [
          unit_revision.resource_id,
          page_revision.resource_id,
          page_2_revision.resource_id,
          page_3_revision.resource_id,
          page_4_revision.resource_id
        ],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    all_revisions =
      [
        page_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        page_5_revision,
        unit_revision,
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
      page_3_revision: page_3_revision,
      unit_revision: unit_revision,
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
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      assert has_element?(lcd, "img[src='/images/course_default.png']")
    end

    test "renders poster image if the page revision has one", %{
      conn: conn,
      project: project,
      page_2_revision: page_2_revision,
      project_hierarchy: project_hierarchy
    } do
      form =
        page_2_revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: page_2_revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
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
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
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
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
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
             |> Floki.parse_document!()
             |> Floki.find("img")
             |> Floki.attribute("src")
             |> hd() =~
               "b.jpg"

      assert render(first_image)
             |> Floki.parse_document!()
             |> Floki.find("img")
             |> Floki.attribute("class")
             |> hd() =~ "!outline-[7px] outline-blue-400"
    end

    test "upload text adapts considering if there are no previous uploaded images", %{
      conn: conn,
      project: project,
      page_revision: revision,
      project_hierarchy: project_hierarchy
    } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
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
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
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
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      # this mock is for the 2 images previously uploaded
      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: %{contents: [%{key: "a.jpg"}, %{key: "b.jpg"}]}}}
      end)

      assert element(lcd, "img[role='poster_image']")
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("img")
             |> Floki.attribute("src")
             |> hd() =~
               "/images/course_default.png"

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
      path = "assets/static/images/course_default.png"

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

      refute element(lcd, "img[role='poster_image']")
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("img")
             |> Floki.attribute("src")
             |> hd() =~
               "/images/course_default.png"
    end

    test "can Cancel image selection after upload has been completed, go back to the first modal step, and the initial poster image should not have changed",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
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
      path = "assets/static/images/course_default.png"

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
               "img[src='/images/course_default.png']"
             )
    end

    test "can select a previously uploaded image (and see it in the general step after clicking on 'Select')",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
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
             |> Floki.parse_document!()
             |> Floki.find("img")
             |> Floki.attribute("class")
             |> hd() =~ "!outline-[7px] outline-blue-400"

      # select an image from the list (it should be styled as the selected one)
      lcd
      |> element("button[data-filename='c.jpg']")
      |> render_click()

      selected_image =
        element(lcd, "button[data-filename='c.jpg'] img")

      assert render(selected_image)
             |> Floki.parse_document!()
             |> Floki.find("img")
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
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
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
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
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
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
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
                           "poster_image" => "/images/course_default.png",
                           "title" => "revision A",
                           "duration_minutes" => "20",
                           "explanation_strategy" => %{"type" => "none"},
                           "graded" => "false",
                           "purpose" => "foundation"
                         }
                       }}
    end

    test "renders no intro video if revision does not have one defined", %{
      conn: conn,
      project: project,
      page_revision: revision,
      project_hierarchy: project_hierarchy
    } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      refute has_element?(lcd, "video")
    end

    test "renders intro video if the page revision has one S3 url defined", %{
      conn: conn,
      project: project,
      page_2_revision: page_2_revision,
      project_hierarchy: project_hierarchy
    } do
      form =
        page_2_revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: page_2_revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      assert has_element?(
               lcd,
               "video[data-filename='b.mp4']"
             )
    end

    test "renders youtube intro video if the page revision has one youtube url defined", %{
      conn: conn,
      project: project,
      page_3_revision: page_3_revision,
      project_hierarchy: project_hierarchy
    } do
      form =
        page_3_revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: page_3_revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      # the youtube url is converted to a valid youtube embed url
      assert has_element?(
               lcd,
               "iframe[src='https://www.youtube.com/embed/i8Pq1jpM3PE?autoplay=0&rel=0']"
             )
    end

    test "lists previous uploaded videos (s3 and unique youtube links) in the intro video selection step",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: %{contents: [%{key: "a.mp4"}, %{key: "b.mp4"}]}}}
      end)

      # go to video selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=intro_video]", "Select")
      |> render_click()

      assert has_element?(
               lcd,
               "button[data-filename='a.mp4']"
             )

      assert has_element?(
               lcd,
               "button[data-filename='b.mp4']"
             )

      assert has_element?(
               lcd,
               "button[id='youtube_click_interceptor_https://www.youtube.com/embed/i8Pq1jpM3PE?autoplay=0&rel=0']"
             )
    end

    test "current selected video is listed first and styled with a blue outline when rendering the video selection step",
         %{
           conn: conn,
           project: project,
           page_2_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok,
         %{
           status_code: 200,
           body: %{contents: [%{key: "a.mp4"}, %{key: "b.mp4"}, %{key: "c.mp4"}]}
         }}
      end)

      # go to video selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=intro_video]", "Select")
      |> render_click()

      first_video = element(lcd, "button[phx-click=select-resource]:first-of-type video")

      assert render(first_video)
             |> Floki.parse_document!()
             |> Floki.find("video")
             |> Floki.attribute("data-filename")
             |> hd() =~
               "b.mp4"

      assert render(first_video)
             |> Floki.parse_document!()
             |> Floki.find("video")
             |> Floki.attribute("class")
             |> hd() =~ "!outline-[7px] outline-blue-400"
    end

    test "can upload a video to S3 and select is as intro video", %{
      conn: conn,
      project: project,
      page_revision: revision,
      project_hierarchy: project_hierarchy
    } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      # this mock is for the 2 videos previously uploaded
      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: %{contents: [%{key: "a.mp4"}, %{key: "b.mp4"}]}}}
      end)

      # the + icon is shown, since there is no intro video for that page
      assert has_element?(
               lcd,
               ~s{i[class="fa-solid fa-circle-plus scale-[200%] text-gray-400"]}
             )

      # go to video selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=intro_video]", "Select")
      |> render_click()

      refute has_element?(lcd, "video[id=uploaded_video_preview]")

      # this mock is for the video that will be uploaded
      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200}}
      end)

      # upload a video
      path = "assets/static/images/course_default.png"

      video =
        file_input(lcd, "#upload-form", :intro_video, [
          %{
            last_modified: 1_594_171_879_000,
            name: "myvideo.mp4",
            content: File.read!(path),
            type: "video/mp4"
          }
        ])

      render_upload(video, "myvideo.mp4")

      # can see the uploaded video
      assert has_element?(lcd, "video[id=uploaded_video_preview]")

      # save changes and go back to general step (the uploaded video should be displayed)
      lcd
      |> element("#upload-form")
      |> render_submit(%{})

      lcd
      |> element("button[phx-click=change_step]", "Select")
      |> render_click()

      # the + icon is NOT shown, since there is a selected intro video for that page
      refute has_element?(
               lcd,
               ~s{i[class="fa-solid fa-circle-plus scale-[200%] text-gray-400"]}
             )
    end

    test "can paste a youtube link and select it as intro video", %{
      conn: conn,
      project: project,
      page_revision: revision,
      project_hierarchy: project_hierarchy
    } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: %{contents: []}}}
      end)

      # the youtube video is not yet selected in the general step
      refute has_element?(
               lcd,
               "iframe[src='https://www.youtube.com/embed/NcIvqnxd4c8?autoplay=0&rel=0']"
             )

      pasted_youtube_url =
        "https://youtu.be/NcIvqnxd4c8"

      # go to video selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=intro_video]", "Select")
      |> render_click()

      refute has_element?(
               lcd,
               "iframe[src='https://www.youtube.com/embed/NcIvqnxd4c8?autoplay=0&rel=0']"
             )

      # paste the youtube link
      form(lcd, "#youtube_url_form")
      |> render_change(%{"intro_video" => %{"url" => pasted_youtube_url}})

      assert has_element?(
               lcd,
               "iframe[src='https://www.youtube.com/embed/NcIvqnxd4c8?autoplay=0&rel=0']"
             )

      # select the youtube link and go back to the general step
      lcd
      |> element("button[phx-click=change_step]", "Select")
      |> render_click()

      # the youtube video is now selected in the general step
      assert has_element?(
               lcd,
               "iframe[src='https://www.youtube.com/embed/NcIvqnxd4c8?autoplay=0&rel=0']"
             )
    end

    test "if an invalid youtube url is pasted as an intro video, the form shows the corresponding error",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: %{contents: []}}}
      end)

      # go to video selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=intro_video]", "Select")
      |> render_click()

      # paste an invalid link
      form(lcd, "#youtube_url_form")
      |> render_change(%{"intro_video" => %{"url" => "some_invalid_link"}})

      assert render(lcd) =~ "must be a valid YouTube URL"
    end

    test "can Cancel video selection after upload has been completed, go back to the first modal step, and the initial intro video should not have changed",
         %{
           conn: conn,
           project: project,
           page_3_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok,
         %{
           status_code: 200,
           body: %{contents: [%{key: "a.mp4"}, %{key: "b.mp4"}, %{key: "c.mp4"}]}
         }}
      end)

      assert has_element?(
               lcd,
               "iframe[src='https://www.youtube.com/embed/i8Pq1jpM3PE?autoplay=0&rel=0']"
             )

      # go to video selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=intro_video]", "Select")
      |> render_click()

      # upload a video
      path = "assets/static/images/course_default.png"

      video =
        file_input(lcd, "#upload-form", :intro_video, [
          %{
            last_modified: 1_594_171_879_000,
            name: "myvideo.mp4",
            content: File.read!(path),
            type: "video/mp4"
          }
        ])

      render_upload(video, "myvideo.mp4")

      # cancel and go back to general step
      lcd
      |> element("button[phx-click=change_step]", "Cancel")
      |> render_click()

      # the intro video has not changed
      assert has_element?(
               lcd,
               "iframe[src='https://www.youtube.com/embed/i8Pq1jpM3PE?autoplay=0&rel=0']"
             )
    end

    test "can select a previously uploaded video (and see it in the general step after clicking on 'Select')",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok,
         %{
           status_code: 200,
           body: %{contents: [%{key: "a.mp4"}, %{key: "b.mp4"}, %{key: "c.mp4"}]}
         }}
      end)

      refute has_element?(
               lcd,
               "video[data-filename='c.mp4']"
             )

      # go to video selection step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=intro_video]", "Select")
      |> render_click()

      not_yet_selected_video =
        element(lcd, "button[data-filename='c.mp4'] video")

      refute render(not_yet_selected_video)
             |> Floki.parse_document!()
             |> Floki.find("video")
             |> Floki.attribute("class")
             |> hd() =~ "!outline-[7px] outline-blue-400"

      # select a video from the list (it should be styled as the selected one)
      lcd
      |> element("button[data-filename='c.mp4']")
      |> render_click()

      selected_video =
        element(lcd, "button[data-filename='c.mp4'] video")

      assert render(selected_video)
             |> Floki.parse_document!()
             |> Floki.find("video")
             |> Floki.attribute("class")
             |> hd() =~ "!outline-[7px] outline-blue-400"

      # go back to general step (the selected video should be displayed)
      lcd
      |> element("button[phx-click=change_step]", "Select")
      |> render_click()

      assert has_element?(
               lcd,
               "video[data-filename='c.mp4']"
             )
    end

    test "can remove the selected intro video and poster image in the general step", %{
      conn: conn,
      project: project,
      page_2_revision: revision,
      project_hierarchy: project_hierarchy
    } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      assert has_element?(lcd, "img[data-filename='b.jpg']")
      assert has_element?(lcd, "video[data-filename='b.mp4']")

      element(lcd, "button[phx-click=clear-resource][phx-value-resource_name=poster_image]")
      |> render_click()

      element(lcd, "button[phx-click=clear-resource][phx-value-resource_name=intro_video]")
      |> render_click()

      refute has_element?(lcd, "img[data-filename='b.jpg']")
      refute has_element?(lcd, "video[data-filename='b.mp4']")
    end

    test "renders the intro content if the revision is a page (practice, graded, exploration, etc)",
         %{
           conn: conn,
           project: project,
           page_revision: revision,
           project_hierarchy: project_hierarchy
         } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      assert has_element?(
               lcd,
               "label",
               "Introduction content"
             )
    end

    test "renders the intro content if the revision is a container", %{
      conn: conn,
      project: project,
      unit_revision: revision,
      project_hierarchy: project_hierarchy
    } do
      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          form: form
        })

      assert has_element?(
               lcd,
               "label",
               "Introduction content"
             )

      assert render(lcd) =~ "Some intro content text!"
    end

    test "can edit the intro content", %{
      conn: conn,
      project: project,
      unit_revision: revision,
      project_hierarchy: project_hierarchy,
      author: author
    } do
      session_context = %OliWeb.Common.SessionContext{
        browser_timezone: "utc",
        local_tz: "utc",
        author: author,
        user: author,
        is_liveview: true
      }

      form =
        revision
        |> Oli.Resources.change_revision()
        |> Phoenix.Component.to_form()

      {:ok, lcd, _html} =
        live_component_isolated(conn, OliWeb.Curriculum.OptionsModalContent, %{
          revision: revision,
          redirect_url: "some_redirect_url",
          project_hierarchy: project_hierarchy,
          project: project,
          validate: "validate-options",
          submit: "save-options",
          cancel: "restart_options_modal",
          ctx: session_context,
          form: form
        })

      assert render(lcd) =~ "Some intro content text!"

      # go to the intro content step
      lcd
      |> element("button[phx-click=change_step][phx-value-target_step=intro_content]", "Edit")
      |> render_click()

      lcd
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.find(~s{div[data-live-react-class="Components.RichTextEditor"]})
      |> Floki.attribute("data-live-react-props")
      |> hd() =~
        "Some intro content text!"
    end
  end
end
