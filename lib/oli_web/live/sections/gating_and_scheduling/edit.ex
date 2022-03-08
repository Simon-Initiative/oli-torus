defmodule OliWeb.Sections.GatingAndScheduling.Edit do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias OliWeb.Sections.Mount
  alias OliWeb.Delivery.Sections.GatingAndScheduling.GatingConditionStore
  alias OliWeb.Sections.GatingAndScheduling.Form
  alias OliWeb.Common.SessionContext
  alias Oli.Delivery.Gating

  def mount(
        %{"id" => gating_condition_id},
        %{"section_slug" => section_slug} = session,
        socket
      ) do
    id = String.to_integer(gating_condition_id)

    {parent_gate_id, title} =
      case Gating.get_gating_condition!(id) do
        %{parent_id: nil} -> {nil, "Edit Gating Condition"}
        %{parent_id: parent_id} -> {parent_id, "Edit Student Exception"}
      end

    context = SessionContext.init(session)

    case Mount.for(section_slug, session) do
      {:admin, _author, section} ->
        {:ok,
         GatingConditionStore.init(
           socket,
           __MODULE__,
           section,
           context,
           title,
           parent_gate_id,
           id
         )}

      {:user, _current_user, section} ->
        {:ok,
         GatingConditionStore.init(
           socket,
           __MODULE__,
           section,
           context,
           title,
           parent_gate_id,
           id
         )}
    end
  end

  def render(assigns) do
    ~F"""
    {render_modal(assigns)}
    <div class="container">
      <h3>{@title}</h3>

      <Form id="new_gating_contition" section={@section} gating_condition={@gating_condition} parent_gate={@parent_gate} count_exceptions={@count_exceptions} create_or_update={:update} />
    </div>
    """
  end

  def handle_event(event, params, socket),
    do: GatingConditionStore.handle_event(event, params, socket)
end
