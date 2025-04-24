defmodule OliWeb.LiveSessionPlugs.SetScheduledResourcesFlag do
  @moduledoc """
  This plug sets the `has_scheduled_resources?` flag checking the section's scheduled_resources in the SectionResourceDepot.
  This flag will be used to conditionally render the Schedule link in the sidebar and
  to adapt the student agenda depending on it's value.
  """

  alias Oli.Delivery.Sections.SectionResourceDepot

  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, _params, _session, %{assigns: %{section: section}} = socket)
      when not is_nil(section) do
    {:cont,
     assign(socket,
       has_scheduled_resources?: SectionResourceDepot.has_scheduled_resources?(section.id)
     )}
  end

  def on_mount(:default, _params, _session, socket), do: {:cont, socket}
end
