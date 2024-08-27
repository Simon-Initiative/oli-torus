defmodule OliWeb.LiveSessionPlugs.RedirectToLessonTest do
  use OliWeb.ConnCase
  import Oli.Factory

  alias Oli.Resources.ResourceType
  alias OliWeb.LiveSessionPlugs.RedirectToLesson

  defp graded_page_revision do
    insert(:revision,
      resource_type_id: ResourceType.get_id_by_type("page"),
      graded: true
    )
  end

  test "redirects a graded page to lesson page when page state is in progress" do
    graded_page_revision = graded_page_revision()

    {:halt, updated_socket} =
      RedirectToLesson.on_mount(
        :default,
        %{
          "section_slug" => "some-section-slug",
          "revision_slug" => graded_page_revision.slug,
          "request_path" => "some-request-path",
          "selected_view" => "gallery"
        },
        %{},
        %Phoenix.LiveView.Socket{
          assigns: %{
            page_context:
              build(:page_context,
                page: graded_page_revision,
                progress_state: :in_progress
              )
          }
        }
      )

    assert updated_socket.redirected ==
             {:redirect,
              %{
                to:
                  "/sections/some-section-slug/lesson/#{graded_page_revision.slug}?request_path=some-request-path&selected_view=gallery"
              }}
  end

  test "redirects a graded page to lesson page when page state is revised" do
    graded_page_revision = graded_page_revision()

    {:halt, updated_socket} =
      RedirectToLesson.on_mount(
        :default,
        %{
          "section_slug" => "some-section-slug",
          "revision_slug" => graded_page_revision.slug,
          "request_path" => "some-request-path",
          "selected_view" => "gallery"
        },
        %{},
        %Phoenix.LiveView.Socket{
          assigns: %{
            page_context:
              build(:page_context,
                page: graded_page_revision,
                progress_state: :revised
              )
          }
        }
      )

    assert updated_socket.redirected ==
             {:redirect,
              %{
                to:
                  "/sections/some-section-slug/lesson/#{graded_page_revision.slug}?request_path=some-request-path&selected_view=gallery"
              }}
  end

  test "does not redirect a graded page when page state is not in progress" do
    graded_page_revision = graded_page_revision()

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        page_context:
          build(:page_context,
            page: graded_page_revision,
            progress_state: :not_started
          )
      }
    }

    assert {:cont, ^socket} =
             RedirectToLesson.on_mount(
               :default,
               %{
                 "section_slug" => "some-section-slug",
                 "revision_slug" => graded_page_revision.slug
               },
               %{},
               socket
             )
  end

  test "does not redirect graded page review" do
    graded_page_revision = graded_page_revision()

    {:cont, updated_socket} =
      RedirectToLesson.on_mount(
        :default,
        %{
          "section_slug" => "some-section-slug",
          "revision_slug" => graded_page_revision.slug,
          "attempt_guid" => "some-attempt-guid"
        },
        %{},
        %Phoenix.LiveView.Socket{}
      )

    refute updated_socket.redirected
  end
end
