defmodule OliWeb.Delivery.Instructor.BankSelectionManagerLive do
  use OliWeb, :live_view

  alias Oli.Delivery.InstructorCustomizations
  alias OliWeb.Components.Delivery.Layouts
  alias OliWeb.Delivery.Instructor.{PreviewReturn, PreviewRoutes}

  def mount(
        %{"revision_slug" => revision_slug, "selection_id" => selection_id} = params,
        _session,
        socket
      ) do
    section = socket.assigns.section
    navigation_params = navigation_params(params, section.slug)

    case InstructorCustomizations.resolve_bank_selection_preview_target(
           section,
           revision_slug,
           selection_id
         ) do
      {:error, {:not_found, :page}} ->
        {:ok, redirect(socket, to: PreviewRoutes.learn_path(section.slug, navigation_params))}

      {:error, {:invalid_page_type, :adaptive}} ->
        {:ok,
         redirect(
           socket,
           to:
             PreviewRoutes.page_path(
               section.slug,
               revision_slug,
               adaptive_redirect_params(params)
             )
         )}

      {:error, {:not_found, :selection}} ->
        {:ok,
         socket
         |> put_flash(:error, "We couldn’t find that activity bank selection for this page.")
         |> redirect(
           to: PreviewRoutes.lesson_path(section.slug, revision_slug, navigation_params)
         )}

      {:ok, revision, selection} ->
        {:ok,
         socket
         |> assign(
           page_revision: revision,
           current_page_resource_id: revision.resource_id,
           selection: selection,
           selection_id: selection_id,
           navigation_params: navigation_params,
           request_path: PreviewRoutes.lesson_path(section.slug, revision.slug, navigation_params)
         )}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Unable to open this activity bank manager.")
         |> redirect(
           to: PreviewRoutes.lesson_path(section.slug, revision_slug, navigation_params)
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div id="bank-selection-manager" data-preview-mode={@preview_mode}>
      <Layouts.instructor_preview_header return_context={@instructor_preview_return} />
      <Layouts.header
        ctx={@ctx}
        is_admin={@is_admin}
        section={@section}
        preview_mode={@preview_mode}
        sidebar_expanded={true}
        instructor_preview_return={@instructor_preview_return}
        include_logo
      />

      <div class="flex-1 flex flex-col w-full">
        <div class="flex-1 mt-4 sm:mt-20 px-4 sm:px-[80px] relative">
          <div class="container mx-auto max-w-[1200px] pb-20 pt-6">
            <div class="rounded-lg border border-Border-border-default bg-Surface-surface-primary p-6">
              <h1 class="text-2xl font-semibold text-Text-text-high">Manage Questions</h1>
              <p class="mt-2 text-sm text-Text-text-low">
                Selection manager route initialized for selection <span class="font-semibold">{@selection_id}</span>.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp navigation_params(params, section_slug) do
    %{}
    |> maybe_put_sanitized_navigation_param("return_to", params["return_to"], section_slug)
    |> maybe_put_sanitized_navigation_param("request_path", params["request_path"], section_slug)
  end

  defp adaptive_redirect_params(params) do
    section_slug = params["section_slug"]

    []
    |> maybe_put_adaptive_redirect_param(:return_to, params["return_to"], section_slug)
    |> maybe_put_adaptive_redirect_param(:request_path, params["request_path"], section_slug)
  end

  defp maybe_put_sanitized_navigation_param(navigation_params, _key, value, _section_slug)
       when value in [nil, ""] do
    navigation_params
  end

  defp maybe_put_sanitized_navigation_param(navigation_params, key, value, section_slug)
       when is_binary(value) do
    case PreviewReturn.sanitize_return_to(value, section_slug) do
      ^value -> Map.put(navigation_params, key, value)
      _fallback -> navigation_params
    end
  end

  defp maybe_put_sanitized_navigation_param(navigation_params, _key, _value, _section_slug),
    do: navigation_params

  defp maybe_put_adaptive_redirect_param(params, _key, value, _section_slug)
       when value in [nil, ""] do
    params
  end

  defp maybe_put_adaptive_redirect_param(params, key, value, section_slug)
       when is_binary(value) and is_binary(section_slug) do
    case PreviewReturn.sanitize_return_to(value, section_slug) do
      ^value -> Keyword.put(params, key, value)
      _fallback -> params
    end
  end

  defp maybe_put_adaptive_redirect_param(params, _key, _value, _section_slug), do: params
end
