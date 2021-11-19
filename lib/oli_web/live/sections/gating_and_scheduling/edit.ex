defmodule OliWeb.Sections.GatingAndScheduling.Edit do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias OliWeb.Sections.Mount
  alias OliWeb.Delivery.Sections.GatingAndScheduling.GatingConditionStore
  alias OliWeb.Sections.GatingAndScheduling.Form

  def mount(
        %{"id" => gating_condition_id},
        %{"section_slug" => section_slug} = session,
        socket
      ) do
    case Mount.for(section_slug, session) do
      {:admin, _author, section} ->
        {:ok,
         GatingConditionStore.init(
           socket,
           __MODULE__,
           section,
           "Edit Gating Condition",
           String.to_integer(gating_condition_id)
         )}

      {:user, _current_user, section} ->
        {:ok,
         GatingConditionStore.init(
           socket,
           __MODULE__,
           section,
           "Edit Gating Condition",
           String.to_integer(gating_condition_id)
         )}
    end
  end

  def render(assigns) do
    ~F"""
    {render_modal(assigns)}
    <div class="container">
      <h3>{@title}</h3>

      <Form id="new_gating_contition" section={@section} gating_condition={@gating_condition} create_or_update={:update} />
    </div>
    """
  end

  def handle_event(event, params, socket),
    do: GatingConditionStore.handle_event(event, params, socket)
end
