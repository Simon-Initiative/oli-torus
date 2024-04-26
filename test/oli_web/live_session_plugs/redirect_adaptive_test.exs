defmodule OliWeb.LiveSessionPlugs.RedirectAdaptiveChromelessTest do
  use OliWeb.ConnCase
  import Oli.Factory

  alias Oli.Resources.ResourceType
  alias OliWeb.LiveSessionPlugs.RedirectAdaptiveChromeless

  defp adaptive_chromeless_page_revision do
    insert(:revision,
      resource_type_id: ResourceType.get_id_by_type("page"),
      graded: true,
      content: %{
        model: [],
        advancedDelivery: true,
        displayApplicationChrome: false,
        additionalStylesheets: [
          "/css/delivery_adaptive_themes_default_light.css"
        ]
      }
    )
  end

  defp page_revision do
    insert(:revision,
      resource_type_id: ResourceType.get_id_by_type("page"),
      graded: true,
      max_attempts: 5,
      content: %{
        model: [],
        advancedDelivery: false,
        displayApplicationChrome: false
      }
    )
  end

  test "redirects an adaptive chromeless page review" do
    adaptive_chromeless_page_revision = adaptive_chromeless_page_revision()

    {:halt, updated_socket} =
      RedirectAdaptiveChromeless.on_mount(
        :default,
        %{
          "section_slug" => "some-section-slug",
          "revision_slug" => adaptive_chromeless_page_revision.slug,
          "attempt_guid" => "some-attempt-guid"
        },
        %{},
        %Phoenix.LiveView.Socket{}
      )

    assert updated_socket.redirected ==
             {:redirect,
              %{
                to:
                  "/sections/some-section-slug/page/#{adaptive_chromeless_page_revision.slug}/attempt/some-attempt-guid/review"
              }}
  end

  test "redirects an adaptive chromeless page" do
    adaptive_chromeless_page_revision = adaptive_chromeless_page_revision()

    {:halt, updated_socket} =
      RedirectAdaptiveChromeless.on_mount(
        :default,
        %{
          "section_slug" => "some-section-slug",
          "revision_slug" => adaptive_chromeless_page_revision.slug
        },
        %{},
        %Phoenix.LiveView.Socket{}
      )

    assert updated_socket.redirected ==
             {:redirect,
              %{
                to:
                  "/sections/some-section-slug/adaptive_lesson/#{adaptive_chromeless_page_revision.slug}"
              }}
  end

  test "does not redirect a non-adaptive chromeless page review" do
    non_adaptive_chromeless_page_revision = page_revision()

    {:cont, updated_socket} =
      RedirectAdaptiveChromeless.on_mount(
        :default,
        %{
          "section_slug" => "some-section-slug",
          "revision_slug" => non_adaptive_chromeless_page_revision.slug,
          "attempt_guid" => "some-attempt-guid"
        },
        %{},
        %Phoenix.LiveView.Socket{}
      )

    refute updated_socket.redirected
  end

  test "does not redirect a non-adaptive chromeless page" do
    non_adaptive_chromeless_page_revision = page_revision()

    {:cont, updated_socket} =
      RedirectAdaptiveChromeless.on_mount(
        :default,
        %{
          "section_slug" => "some-section-slug",
          "revision_slug" => non_adaptive_chromeless_page_revision.slug
        },
        %{},
        %Phoenix.LiveView.Socket{}
      )

    refute updated_socket.redirected
  end
end
