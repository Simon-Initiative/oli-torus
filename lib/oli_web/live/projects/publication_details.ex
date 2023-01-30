defmodule OliWeb.Projects.PublicationDetails do
  use Surface.Component

  alias OliWeb.Common.Utils

  prop active_publication_changes, :any, required: true
  prop context, :struct, required: true
  prop has_changes, :boolean, required: true
  prop latest_published_publication, :any, required: true
  prop parent_pages, :map, required: true
  prop project, :struct, required: true

  def render(assigns) do
    ~F"""
      <h5 class="mb-0">Publication Details</h5>
      <div class="flex flex-row items-center">
        <div class="flex-1">
          Publish your project to give instructors access to the latest changes.
        </div>
        <div>
          <button class="btn btn-outline-primary whitespace-nowrap" :on-click="display_lti_connect_modal">
            <i class="fa-solid fa-plug-circle-bolt"></i> Connect with LTI 1.3
          </button>
        </div>
      </div>
      {#case @latest_published_publication}
        {#match %{edition: current_edition, major: current_major, minor: current_minor}}
          <div class="badge badge-secondary">
            Latest Publication: {Utils.render_version(current_edition, current_major, current_minor)}
          </div>

        {#match _}
      {/case}

      {#case {@has_changes, @active_publication_changes}}
        {#match {true, nil}}
          <h6 class="my-3"><strong>This project has not been published yet</strong></h6>
        {#match {false, _}}
          <h6 class="my-3">
            Published <strong>{Utils.render_date(@latest_published_publication, :published, @context)}</strong>.
            There are <strong>no changes</strong> since the latest publication.
          </h6>
        {#match {true, changes}}
          <div class="my-3">Last published <strong>{Utils.render_date(@latest_published_publication, :published, @context)}</strong>.
          There {if change_count(changes) == 1 do "is" else "are" end} <strong>{change_count(changes)}</strong> pending {if change_count(changes) == 1 do "change" else "changes" end} since last publish:</div>
          {#for {status, %{revision: revision}}  <- Map.values(changes)}
            <div class="flex items-center my-2">
              <span class={"badge badge-secondary badge-#{status} mr-2"}>{status}</span>
              {#case status}
                {#match :deleted}
                  <span>{revision.title}</span>
                {#match _}
                  <span>{OliWeb.Common.Links.resource_link(revision, @parent_pages, @project)}</span>
              {/case}
            </div>
          {/for}
      {/case}
    """
  end

  defp change_count(changes),
    do:
      changes
      |> Map.values()
      |> Enum.count()
end
