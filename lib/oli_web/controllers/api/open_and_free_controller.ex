defmodule OliWeb.Api.OpenAndFreeController do
  use OliWeb, :controller
  alias Oli.Delivery.Sections

  @doc """
  Provides API access to the open and free sections that are open for registration.
  """
  def index(conn, _params) do
    case Oli.Utils.LoadTesting.enabled?() do
      true ->
        sections =
          Sections.list_open_and_free_sections()
          |> Enum.filter(fn s -> s.registration_open and !s.requires_enrollment end)
          |> Enum.map(fn section ->
            %{
              slug: section.slug,
              url: ~p"/sections/#{section.slug}"
            }
          end)

        json(conn, sections)

      false ->
        error(conn, 503, "Load testing not enabled")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
