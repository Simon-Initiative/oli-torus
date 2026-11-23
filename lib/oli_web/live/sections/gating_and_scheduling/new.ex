defmodule OliWeb.Sections.GatingAndScheduling.New do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias OliWeb.Sections.Mount
  alias OliWeb.Delivery.Sections.GatingAndScheduling.GatingConditionStore
  alias OliWeb.Sections.GatingAndScheduling.Form
  alias OliWeb.Common.Breadcrumb
  alias Oli.Authoring.Course.Project

  on_mount OliWeb.LiveSessionPlugs.SetRouteName

  def mount(
        %{"section_slug" => section_slug} = params,
        _session,
        socket
      ) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {user_type, actor, section} ->
        socket = assign(socket, actor: actor)

        # A student exception's gate must belong to this section
        case parent_gate(section, Map.get(params, "parent_gate_id")) do
          :not_found ->
            Mount.handle_error(socket, {:error, :not_found})

          parent_gate ->
            {parent_gate_id, title} =
              case parent_gate do
                nil -> {nil, "Create Gating Condition"}
                gate -> {gate.id, "Create Student Exception"}
              end

            {:ok,
             GatingConditionStore.init(
               socket,
               __MODULE__,
               section,
               socket.assigns.ctx,
               title,
               parent_gate_id,
               user_type,
               nil,
               product_path_base(section, params)
             )}
        end
    end
  end

  defp parent_gate(_section, nil), do: nil

  defp parent_gate(section, id) do
    case Oli.Delivery.Gating.get_section_gating_condition(section.id, id) do
      nil -> :not_found
      gate -> gate
    end
  end

  def render(assigns) do
    ~H"""
    {render_modal(assigns)}
    <div class="container">
      <h3>{@title}</h3>

      <Form.render
        section={@section}
        gating_condition={@gating_condition}
        parent_gate={@parent_gate}
        count_exceptions={@count_exceptions}
        ctx={@ctx}
        product_path_base={@product_path_base}
      />
    </div>
    """
  end

  def handle_event(event, params, socket),
    do: GatingConditionStore.handle_event(event, params, socket)

  defp product_path_base(%{type: :blueprint} = section, %{"project_id" => project_slug}) do
    Breadcrumb.product_path_base(section, :workspaces, %Project{slug: project_slug})
  end

  defp product_path_base(%{type: :blueprint} = section, _params),
    do: Breadcrumb.product_path_base(section, nil, nil)

  defp product_path_base(_section, _params), do: nil
end
