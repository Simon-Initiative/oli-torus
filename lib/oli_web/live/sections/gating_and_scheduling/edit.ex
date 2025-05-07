defmodule OliWeb.Sections.GatingAndScheduling.Edit do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias OliWeb.Sections.Mount
  alias OliWeb.Delivery.Sections.GatingAndScheduling.GatingConditionStore
  alias OliWeb.Sections.GatingAndScheduling.Form
  alias Oli.Delivery.Gating

  def mount(
        %{"id" => gating_condition_id, "section_slug" => section_slug},
        _session,
        socket
      ) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {user_type, _user, section} ->
        id = String.to_integer(gating_condition_id)

        {parent_gate_id, title} =
          case Gating.get_gating_condition!(id) do
            %{parent_id: nil} -> {nil, "Edit Gating Condition"}
            %{parent_id: parent_id} -> {parent_id, "Edit Student Exception"}
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
           user_type,
           id
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
        create_or_update={:update}
        ctx={@ctx}
      />
    </div>
    """
  end

  def handle_event(event, params, socket),
    do: GatingConditionStore.handle_event(event, params, socket)
end
