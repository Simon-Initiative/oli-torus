defmodule OliWeb.Layouts do
  use OliWeb, :html

  import OliWeb.Components.Utils
  import OliWeb.Components.Delivery.Layouts

  alias Oli.Delivery.Sections

  embed_templates "layouts/*"

  def assistant_available?(assigns) do
    case Map.fetch(assigns, :assistant_available?) do
      {:ok, assistant_available?} ->
        assistant_available?

      :error ->
        case {Map.get(assigns, :section), Map.get(assigns, :page_context)} do
          {%Sections.Section{} = section, %{page: page}} ->
            Sections.assistant_enabled_for_page?(section, page)

          _ ->
            false
        end
    end
  end
end
