defmodule OliWeb.Sections.GatingAndScheduling.New do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias OliWeb.Sections.Mount
  alias OliWeb.Delivery.Sections.GatingAndScheduling.GatingConditionStore
  alias OliWeb.Sections.GatingAndScheduling.Form

  def mount(
        %{"section_slug" => section_slug} = params,
        session,
        socket
      ) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {user_type, _user, section} ->
        {parent_gate_id, title} =
          case Map.get(params, "parent_gate_id") do
            nil -> {nil, "Create Gating Condition"}
            id -> {id, "Create Student Exception"}
          end

        ctx = socket.assigns.ctx

        {:ok,
         GatingConditionStore.init(
           socket,
           __MODULE__,
           section,
           ctx,
           title,
           parent_gate_id,
           user_type
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <%= render_modal(assigns) %>
    <div class="container">
      <h3><%= @title %></h3>

      <Form.render
        section={@section}
        gating_condition={@gating_condition}
        parent_gate={@parent_gate}
        count_exceptions={@count_exceptions}
        ctx={@ctx}
      />
    </div>
    """
  end

  def handle_event(event, params, socket),
    do: GatingConditionStore.handle_event(event, params, socket)
end
