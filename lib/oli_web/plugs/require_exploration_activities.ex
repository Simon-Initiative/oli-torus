defmodule Oli.Plugs.RequireExplorationPages do
  import Plug.Conn

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.path_params do
      %{"revision_slug" => revision_slug, "section_slug" => section_slug} ->
        if conn.assigns.section.contains_explorations do
          case Resources.get_resource_from_slug(revision_slug) do
            nil ->
              conn

            %{id: id} ->
              conn
              |> assign(
                :exploration_pages,
                DeliveryResolver.targeted_via_related_to(section_slug, id)
              )
          end
        else
          conn
        end

      _ ->
        conn
    end
  end
end
