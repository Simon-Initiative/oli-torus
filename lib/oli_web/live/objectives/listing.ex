defmodule OliWeb.ObjectivesLive.Listing do
  use Surface.Component

  alias OliWeb.ObjectivesLive.Actions
  alias OliWeb.Router.Helpers, as: Routes

  prop rows, :list, required: true
  prop selected, :string, required: true
  prop project_slug, :string, required: true

  def render(assigns) do
    ~F"""
      <div id="accordion" class="accordion p-3">
        {#for {item, index} <- Enum.with_index(@rows)}
          <div id={item.slug} class="card border border-light mb-2">
            <div class="card-header d-flex justify-content-between p-2" id={"heading#{index}"}>
              <button
                class="btn w-75 text-left"
                data-toggle="collapse"
                data-target={"#collapse#{index}"}
                aria-expanded="true"
                aria-controls={"collapse#{index}"}
                :on-click="set_selected"
                :values={slug: item.slug}>
                {item.title}
              </button>
              <div class="d-flex flex-column font-weight-light small bg-secondary p-2 rounded mr-2">
                <div><i class="fa fa-cubes c0183 mr-1"></i>Sub-Objectives {item.sub_objectives_count}</div>
                <div><i class="far fa-file c0183 mr-1"></i>Pages {item.page_attachments_count}</div>
                <div><i class="fa fa-list mr-1"></i>Activities {item.activity_attachments_count}</div>
              </div>
            </div>

            <div id={"collapse#{index}"} class={"collapse" <> if item.slug == @selected, do: " show", else: ""} aria-labelledby={"heading#{index}"} data-parent="#accordion">
              <div class="card-body">
                <div class="mb-3">
                  <u>Sub-Objectives</u>
                  <ul class="list-group list-group-flush">
                    {#for sub_objective <- item.children}
                      <li class="list-group-item p-2 text-info d-flex sub-obj">
                        <div class="w-75">{sub_objective.title}</div>
                        <div class="ml-2 sub-actions">
                          <button
                            :on-click="display_edit_modal"
                            :values={slug: sub_objective.slug}
                            class="ml-1 btn btn-sm btn-light">
                            <i class="las la-i-cursor"></i>
                          </button>
                          <button
                            :on-click="delete"
                            :values={slug: sub_objective.slug, parent_slug: item.slug}
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
                      <div class="border border-light w-75"></div>
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
