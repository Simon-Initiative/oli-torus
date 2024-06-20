defmodule OliWeb.LiveSessionPlugs.RedirectToPrologueTest do
  use OliWeb.ConnCase
  import Oli.Factory

  alias Oli.Resources.ResourceType
  alias OliWeb.LiveSessionPlugs.RedirectToPrologue

  defp graded_page_revision do
    insert(:revision,
      resource_type_id: ResourceType.get_id_by_type("page"),
      graded: true
    )
  end

  test "redirects a graded page when page state is not in progress" do
    graded_page_revision = graded_page_revision()

    {:halt, updated_socket} =
      RedirectToPrologue.on_mount(
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
                progress_state: :not_started
              )
          }
        }
      )

    assert updated_socket.redirected ==
             {:redirect,
              %{
                to:
                  "/sections/some-section-slug/prologue/#{graded_page_revision.slug}?request_path=some-request-path&selected_view=gallery"
              }}
  end

  test "does not redirect a graded page when page state is in progress" do
    graded_page_revision = graded_page_revision()

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        page_context:
          build(:page_context,
            page: graded_page_revision,
            progress_state: :in_progress
          )
      }
    }

    assert {:cont, ^socket} =
             RedirectToPrologue.on_mount(
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
      RedirectToPrologue.on_mount(
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
