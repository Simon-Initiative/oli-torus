defmodule OliWeb.Analytics do
  @moduledoc """
  Sanitized, route-level analytics context and catalogued product events.

  Context never contains request paths, titles or identifiers of people, sections or
  attempts. The only ID is `course_id`, the base project ID of a course design. Product
  events are defined in `priv/analytics/event_catalog.json` (see `OliWeb.Analytics.Catalog`).
  """

  require Logger

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Authoring.Course.Project
  alias Oli.Resources.{ResourceType, Revision}
  alias OliWeb.Analytics.Catalog
  alias Phoenix.LiveView.JS

  @titles %{
    "delivery" => "Learning",
    "instructor" => "Instructor",
    "authoring" => "Authoring",
    "admin" => "Administration",
    "public" => "Torus"
  }

  defmodule Subject do
    @moduledoc """
    Context inputs captured from full assigns. Views may later slim their assigns, so
    LiveViews capture this once on mount.
    """

    @type t :: %__MODULE__{
            admin?: boolean(),
            system_admin?: boolean(),
            author?: boolean(),
            user: nil | :guest | :lms | :independent,
            section_course_id: pos_integer() | nil,
            project_course_id: pos_integer() | nil,
            page_type: String.t() | nil,
            preview?: boolean(),
            template_preview?: boolean()
          }

    defstruct admin?: false,
              system_admin?: false,
              author?: false,
              user: nil,
              section_course_id: nil,
              project_course_id: nil,
              page_type: nil,
              preview?: false,
              template_preview?: false
  end

  @doc "Whether this deployment has opted into GTM."
  @spec enabled?() :: boolean()
  def enabled? do
    is_binary(Application.get_env(:oli, :analytics, [])[:gtm_container_id])
  end

  @doc """
  Captures the analytics inputs present in `assigns` without querying the database.

  When `mounted` is given, its user and role inputs are kept and only missing course and page
  inputs are filled from `assigns`, so views that load data after mount are covered.
  """
  @spec subject(map(), Subject.t() | nil) :: Subject.t()
  def subject(assigns, mounted \\ nil)

  def subject(assigns, nil) do
    author = Map.get(assigns, :current_author)

    %Subject{
      admin?: Accounts.is_admin?(author),
      system_admin?: Accounts.is_system_admin?(author),
      author?: match?(%Author{}, author),
      user: user_kind(Map.get(assigns, :current_user)),
      section_course_id: section_course_id(Map.get(assigns, :section)),
      project_course_id: project_course_id(Map.get(assigns, :project)),
      page_type: page_type(assigns),
      preview?: Map.get(assigns, :preview_mode) == true,
      template_preview?: Map.get(assigns, :template_preview_mode) == true
    }
  end

  def subject(assigns, %Subject{} = mounted) do
    %Subject{
      mounted
      | section_course_id:
          mounted.section_course_id || section_course_id(Map.get(assigns, :section)),
        project_course_id:
          mounted.project_course_id || project_course_id(Map.get(assigns, :project)),
        page_type: mounted.page_type || page_type(assigns)
    }
  end

  @doc """
  Resolves a GET URL to a Phoenix route template and its event context, or nil for
  unknown/excluded routes. Accepts assigns or a previously captured `Subject`.
  """
  @spec page_context(String.t(), map() | Subject.t()) :: map() | nil
  def page_context(url, assigns_or_subject \\ %{})

  def page_context(url, %Subject{} = subject) do
    %{host: host, path: path} = URI.parse(url)

    case Phoenix.Router.route_info(OliWeb.Router, "GET", path || "/", host || "localhost") do
      :error -> nil
      route_info -> context_for_route(route_info, subject)
    end
  end

  def page_context(url, assigns) when is_map(assigns), do: page_context(url, subject(assigns))

  @doc "Resolves sanitized page context from a root layout connection."
  @spec context_for_conn(Plug.Conn.t()) :: map() | nil
  def context_for_conn(conn) do
    case Phoenix.Router.route_info(OliWeb.Router, conn.method, conn.request_path, conn.host) do
      :error -> nil
      route_info -> context_for_route(route_info, subject(conn.assigns))
    end
  end

  @doc """
  Pushes a catalogued product event to the browser writer in `assets/src/analytics/`, which
  adds the page context and enforces consent and preview suppression.

  Parameters not catalogued for the event, invalid values and context parameters are dropped
  with a warning; uncatalogued events are not sent. Nothing is pushed when the deployment has
  no GTM container or the socket is not connected.
  """
  @spec track(Phoenix.LiveView.Socket.t(), String.t(), map()) :: Phoenix.LiveView.Socket.t()
  def track(socket, name, params \\ %{}) do
    with {:ok, params} <- validate(name, params),
         true <- enabled?() and Phoenix.LiveView.connected?(socket) do
      Phoenix.LiveView.push_event(socket, "analytics:track", %{name: name, params: params})
    else
      _ -> socket
    end
  end

  @doc """
  Appends a browser-side dispatch of a catalogued event to `js`, for actions that never reach
  the server. The writer applies the same context, consent and preview rules as `track/3`.
  """
  @spec js_track(JS.t(), String.t(), map()) :: JS.t()
  def js_track(%JS{} = js, name, params) do
    case validate(name, params) do
      {:ok, params} ->
        JS.dispatch(js, "phx:analytics:track", detail: %{name: name, params: params})

      :error ->
        js
    end
  end

  defp validate(name, params) do
    case Catalog.event_params(name, params) do
      {:ok, params, []} ->
        {:ok, params}

      {:ok, params, dropped} ->
        Logger.warning(
          "Analytics event #{name} dropped parameters not allowed by the catalog: " <>
            Enum.join(dropped, ", ")
        )

        {:ok, params}

      :error ->
        Logger.warning("Dropped analytics event not in the catalog: #{inspect(name)}")
        :error
    end
  end

  defp context_for_route(%{route: route} = info, %Subject{} = subject) do
    case excluded?(route, info) do
      true ->
        nil

      false ->
        area = page_area(route, info)

        %{
          page_path: route,
          page_area: area,
          page_title: Map.fetch!(@titles, area),
          traffic_type: traffic_type(subject),
          user_role: user_role(area, route, subject),
          course_id: course_id(area, subject),
          page_type: subject.page_type || route_page_type(route),
          entry_point: entry_point(area, subject),
          preview_mode: preview_mode(route, subject)
        }
        |> Map.reject(fn {_key, value} -> is_nil(value) end)
    end
  end

  defp excluded?(route, info) do
    String.starts_with?(route, ["/lti", "/api/", "/mcp"]) or
      route == "/sections/:section_slug/payment/new" or
      :lti in info.pipe_through
  end

  defp page_area(route, info) do
    cond do
      String.starts_with?(route, "/admin") or
          Enum.any?(
            info.pipe_through,
            &(&1 in [
                :require_authenticated_admin,
                :require_authenticated_system_admin,
                :require_authenticated_account_admin,
                :require_authenticated_content_admin
              ])
          ) ->
        "admin"

      String.starts_with?(route, "/workspaces/instructor") or
        String.contains?(route, "/instructor_dashboard") or
        :require_independent_instructor in info.pipe_through or
          instructor_layout?(info) ->
        "instructor"

      String.starts_with?(route, ["/authoring", "/workspaces/course_author"]) ->
        "authoring"

      String.starts_with?(route, ["/sections", "/workspaces/student"]) ->
        "delivery"

      true ->
        "public"
    end
  end

  defp instructor_layout?(%{phoenix_live_view: {_module, _action, _opts, session}}) do
    case Map.get(session.extra, :layout) do
      {OliWeb.Layouts, layout} ->
        String.starts_with?(Atom.to_string(layout), "instructor_dashboard")

      _ ->
        false
    end
  end

  defp instructor_layout?(_), do: false

  defp traffic_type(%Subject{system_admin?: true}), do: "internal"
  defp traffic_type(_subject), do: "external"

  defp user_role(_area, _route, %Subject{user: nil, author?: false}), do: nil

  # Section preview routes are only authorized for instructors and administrators.
  defp user_role(area, route, %Subject{} = subject) do
    cond do
      subject.admin? or area == "admin" -> "admin"
      area == "authoring" or subject.template_preview? -> "author"
      area == "instructor" or (area == "delivery" and preview?(route, subject)) -> "instructor"
      subject.user == :guest -> "guest"
      not is_nil(subject.user) -> "learner"
      true -> "author"
    end
  end

  defp course_id("authoring", subject),
    do: subject.project_course_id || subject.section_course_id

  defp course_id(_area, subject), do: subject.section_course_id || subject.project_course_id

  defp entry_point(area, %Subject{section_course_id: id} = subject)
       when area in ["delivery", "instructor"] and is_integer(id) do
    case subject.user do
      :lms -> "lti"
      _ -> "direct"
    end
  end

  defp entry_point(_area, _subject), do: nil

  defp preview_mode(route, subject) do
    cond do
      subject.template_preview? -> "template_preview"
      preview?(route, subject) -> "preview"
      true -> nil
    end
  end

  defp preview?(route, subject), do: subject.preview? or "preview" in String.split(route, "/")

  defp route_page_type(route) do
    case String.contains?(route, "/adaptive_lesson/") do
      true -> "adaptive"
      false -> nil
    end
  end

  defp user_kind(%User{guest: true}), do: :guest
  defp user_kind(%User{independent_learner: false}), do: :lms
  defp user_kind(%User{}), do: :independent
  defp user_kind(_), do: nil

  defp section_course_id(%{base_project_id: id}) when is_integer(id), do: id
  defp section_course_id(_), do: nil

  defp project_course_id(%Project{id: id}) when is_integer(id), do: id
  defp project_course_id(_), do: nil

  # Connected views carry a page context; hard-loaded page requests carry the revision that
  # OliWeb.Plugs.RedirectByAttemptState resolved, so the first page view is already typed.
  defp page_type(assigns) do
    case {Map.get(assigns, :page_context), Map.get(assigns, :page_revision)} do
      {%{page: %Revision{} = page}, _} -> revision_page_type(page)
      {_, %Revision{} = page} -> revision_page_type(page)
      _ -> nil
    end
  end

  defp revision_page_type(page) do
    page_resource_type = ResourceType.id_for_page()

    cond do
      Map.get(page.content || %{}, "advancedDelivery") == true -> "adaptive"
      page.graded -> "graded"
      page.purpose == :application -> "exploration"
      page.resource_type_id == page_resource_type -> "practice"
      true -> "other"
    end
  end
end
