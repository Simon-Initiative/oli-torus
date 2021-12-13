defmodule OliWeb.Api.OpenAndFreeController do
  use OliWeb, :controller
  alias Oli.Delivery.Sections

  @doc """
  Provides API access to the open and free sections that are open for registration.
  """
  def index(conn, _params) do
    sections =
      Sections.list_open_and_free_sections()
      |> Enum.filter(fn s -> s.registration_open end)
      |> Enum.map(fn section ->
        %{
          slug: section.slug,
          url: Routes.page_delivery_path(conn, :index, section.slug)
        }
      end)

    json(conn, sections)
  end
end
