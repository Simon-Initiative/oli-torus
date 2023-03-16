defmodule OliWeb.ObjectivesLive.Listing do
  use Surface.Component

  alias OliWeb.ObjectivesLive.Actions
  alias OliWeb.Router.Helpers, as: Routes

  prop rows, :list, required: true
  prop selected, :string, required: true
  prop project_slug, :string, required: true

  def render(assigns) do
    ~F"""
      <div id="accordion" class="accordion">
        {#for {item, index} <- Enum.with_index(@rows)}
          <div id={item.slug} class="card max-w-full border mb-3 p-0">
            <div class="card-header d-flex justify-content-between p-2" id={"heading#{index}"}>
              <button
                class="flex-1 btn w-75 text-left"
                data-bs-toggle="collapse"
                data-bs-target={"#collapse#{index}"}
                aria-expanded="true"
                aria-controls={"collapse#{index}"}
                phx-click="set_selected"
                phx-value-slug={item.slug}>
                {item.title}
              </button>
              <div class="d-flex flex-column font-weight-light small p-2 pr-4">
                <div><i class="fa fa-cubes c0183 mr-1"></i>Sub-Objectives {item.sub_objectives_count}</div>
                <div><i class="far fa-file c0183 mr-1"></i>Pages {item.page_attachments_count}</div>
                <div><i class="fa fa-list mr-1"></i>Activities {item.activity_attachments_count}</div>
              </div>
            </div>

            <div id={"collapse#{index}"} class={"collapse" <> if item.slug == @selected, do: " show", else: ""} aria-labelledby={"heading#{index}"} data-parent="#accordion">
              <div class="card-body p-4">
                <div class="mb-3">
                  <u>Sub-Objectives</u>
                  <ul class="list-group list-group-flush">
                    {#for sub_objective <- item.children}
                      <li class="list-group-item p-2 text-info d-flex sub-obj">
                        <div class="w-75">{sub_objective.title}</div>
                        <div class="ml-2 sub-actions">
                          <button
                            phx-click="display_edit_modal"
                            phx-value-slug={sub_objective.slug}
                            class="ml-1 btn btn-sm btn-light">
                            <i class="fas fa-i-cursor"></i>
                          </button>
                          <button
                            phx-click="delete"
                            phx-value-slug={sub_objective.slug}
                            phx-value-parent_slug={item.slug}
                            class="ml-1 btn btn-sm btn-danger">
                              <i class="fas fa-trash-alt fa-lg"></i>
                          </button>
                        </div>
                      </li>
                      <div class="border border-light w-75"></div>
                    {/for}
                  </ul>
                </div>
                <div class="mb-3">
                  <u>Pages</u>
                  <ul class="list-group list-group-flush">
                    {#for page <- item.page_attachments}
                      <li class="list-group-item p-2">
                        <a href={Routes.resource_path(OliWeb.Endpoint, :edit, @project_slug, page.slug)}
                          target="_blank"
                          class="text-info">
                          {page.title}
                        </a>
                      </li>
                      <hr class="h-0 my-2 border border-solid border-t-0 border-gray-700 opacity-25 w-75" />
                    {/for}
                  </ul>
                </div>

                <Actions slug={item.slug} />
              </div>
            </div>
          </div>
        {/for}
      </div>
    """
  end
end
