defmodule OliWeb.Sections.GatingAndScheduling.Edit do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias OliWeb.Sections.Mount
  alias OliWeb.Delivery.Sections.GatingAndScheduling.GatingConditionStore
  alias OliWeb.Sections.GatingAndScheduling.Form
  alias Oli.Delivery.Gating
  alias OliWeb.Common.Breadcrumb
  alias Oli.Authoring.Course.Project

  on_mount OliWeb.LiveSessionPlugs.SetRouteName

  def mount(
        %{"id" => gating_condition_id, "section_slug" => section_slug} = params,
        _session,
        socket
      ) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {user_type, actor, section} ->
        socket = assign(socket, actor: actor)

        # Only a gate of this section can be edited from its page
        case Gating.get_section_gating_condition(section.id, gating_condition_id) do
          nil ->
            Mount.handle_error(socket, {:error, :not_found})

          gate ->
            title =
              case gate.parent_id do
                nil -> "Edit Gating Condition"
                _parent_id -> "Edit Student Exception"
              end

            {:ok,
             GatingConditionStore.init(
               socket,
               __MODULE__,
               section,
               socket.assigns.ctx,
               title,
               gate.parent_id,
               user_type,
               gate.id,
               product_path_base(section, params)
             )}
        end
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
        create_or_update={:update}
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
