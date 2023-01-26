defmodule OliWeb.CollaborationLive.SortPosts do
  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.{Field, RadioButton, Select}

  prop sort, :struct, required: true

  def render(assigns) do
    ~F"""
    <Form for={:sort} change="sort" class="d-flex">
      <Select
        field="sort_by"
        options={Date: "inserted_at", "# of Replies": "replies_count"}
        class="custom-select custom-select mr-2"
        selected={@sort.by}
      />

      <Field name="sort_order" class="control w-100 d-flex align-items-center">
        <div class="btn-group btn-group-toggle">
          <label class={"btn btn-outline-secondary" <> if @sort.order == :desc, do: " active", else: ""}>
            <RadioButton value="desc" checked={@sort.order == :desc} opts={hidden: true} />
            <i class="fa fa-sort-amount-down" />
          </label>
          <label class={"btn btn-outline-secondary" <> if @sort.order == :asc, do: " active", else: ""}>
            <RadioButton value="asc" checked={@sort.order == :asc} opts={hidden: true} />
            <i class="fa fa-sort-amount-up" />
          </label>
        </div>
      </Field>
    </Form>
    """
  end
end
