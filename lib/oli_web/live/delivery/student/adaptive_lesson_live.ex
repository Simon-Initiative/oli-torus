defmodule OliWeb.Delivery.Student.AdaptiveLessonLive do
  use OliWeb, :live_view

  import Ecto.Query

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections

  require Logger

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :init_adaptive_context_state}

  # this is an optimization to reduce the memory footprint of the liveview process
  @required_keys_per_assign %{
    section:
      {[:id, :slug, :title, :brand, :lti_1p3_deployment, :customizations], %Sections.Section{}},
    current_user: {[:id, :name, :email], %User{}}
  }

  def mount(_params, _session, socket) do
    if connected?(socket) do
      emit_page_viewed_event(socket)
      send(self(), :gc)
    end

    {:ok, slim_assigns(socket), temporary_assigns: [scripts: [], page_context: %{}]}
  end

  def render(assigns) do
    ~H"""
    <!-- ACTIVITIES -->
    <%= for %{slug: slug, authoring_script: script} <- @activity_types do %>
      <script
        :if={slug == "oli_adaptive"}
        type="text/javascript"
        src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}
      >
      </script>
    <% end %>
    <!-- PARTS -->
    <script
      :for={script <- @part_scripts}
      type="text/javascript"
      src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}
    >
    </script>

    <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/delivery.js")}>
    </script>

    <div id="delivery_container" phx-update="ignore">
      <%= react_component("Components.Delivery", @app_params) %>
    </div>

    <%= OliWeb.LayoutView.additional_stylesheets(%{additional_stylesheets: @additional_stylesheets}) %>

    <script>
      window.userToken = "<%= @user_token %>";
    </script>
    """
  end

  defp emit_page_viewed_event(socket) do
    section = socket.assigns.section
    context = socket.assigns.page_context

    page_sub_type =
      if Map.get(context.page.content, "advancedDelivery", false) do
        "advanced"
      else
        "basic"
      end

    {project_id, publication_id} = get_project_and_publication_ids(section.id, context.page.id)

    emit_page_viewed_helper(
      %Oli.Analytics.XAPI.Events.Context{
        user_id: socket.assigns.current_user.id,
        host_name: host_name(),
        section_id: section.id,
        project_id: project_id,
        publication_id: publication_id
      },
      %{
        attempt_guid: List.first(context.resource_attempts).attempt_guid,
        attempt_number: List.first(context.resource_attempts).attempt_number,
        resource_id: context.page.resource_id,
        timestamp: DateTime.utc_now(),
        page_sub_type: page_sub_type
      }
    )

    socket
  end

  defp emit_page_viewed_helper(
         %Oli.Analytics.XAPI.Events.Context{} = context,
         %{
           attempt_guid: _page_attempt_guid,
           attempt_number: _page_attempt_number,
           resource_id: _page_id,
           timestamp: _timestamp,
           page_sub_type: _page_sub_type
         } = page_details
       ) do
    event = Oli.Analytics.XAPI.Events.Attempt.PageViewed.new(context, page_details)
    Oli.Analytics.XAPI.emit(:page_viewed, event)
  end

  defp get_project_and_publication_ids(section_id, revision_id) do
    # From the SectionProjectPublication table, get the project_id and publication_id
    # where a published resource exists for revision_id
    # and the section_id matches the section_id

    query =
      from sp in Oli.Delivery.Sections.SectionsProjectsPublications,
        join: pr in Oli.Publishing.PublishedResource,
        on: pr.publication_id == sp.publication_id,
        where: sp.section_id == ^section_id and pr.revision_id == ^revision_id,
        select: {sp.project_id, sp.publication_id}

    # Return nil if somehow we cannot resolve this resource.  This is just a guaranteed that
    # we can never throw an error here
    case Oli.Repo.all(query) do
      [] -> {nil, nil}
      other -> hd(other)
    end
  end

  defp host_name() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end

  defp slim_assigns(socket) do
    Enum.reduce(@required_keys_per_assign, socket, fn {assign_name, {required_keys, struct}},
                                                      socket ->
      assign(
        socket,
        assign_name,
        Map.merge(
          struct,
          Map.filter(socket.assigns[assign_name], fn {k, _v} -> k in required_keys end)
        )
      )
    end)
  end
end
