defmodule OliWeb.Sections.GatingAndScheduling.New do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias OliWeb.Sections.Mount
  alias OliWeb.Delivery.Sections.GatingAndScheduling.GatingConditionStore
  alias OliWeb.Sections.GatingAndScheduling.Form
  alias OliWeb.Common.SessionContext

  def mount(
        params,
        %{"section_slug" => section_slug} = session,
        socket
      ) do
    {parent_gate_id, title} =
      case Map.get(params, "parent_gate_id") do
        nil -> {nil, "Create Gating Condition"}
        id -> {id, "Create Student Exception"}
      end

    context = SessionContext.init(session)

    {user_type, _user, section} = Mount.for(section_slug, session)

    {:ok,
     GatingConditionStore.init(
       socket,
       __MODULE__,
       section,
       context,
       title,
       parent_gate_id,
       user_type
     )}
  end

  def render(assigns) do
    ~F"""
    {render_modal(assigns)}
    <div class="container">
      <h3>{@title}</h3>

      <Form id="new_gating_contition" section={@section} gating_condition={@gating_condition} parent_gate={@parent_gate} count_exceptions={@count_exceptions} />
    </div>
    """
  end

  def handle_event(event, params, socket),
    do: GatingConditionStore.handle_event(event, params, socket)
end
