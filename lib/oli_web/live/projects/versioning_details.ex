defmodule OliWeb.Projects.VersioningDetails do
  use Surface.Component

  alias OliWeb.Common.Utils

  alias Surface.Components.Form

  alias Surface.Components.Form.{
    Checkbox,
    Field,
    HiddenInput,
    Label,
    TextArea
  }

  prop active_publication, :any, required: true
  prop active_publication_changes, :any, required: true
  prop changeset, :any, required: true
  prop force_push, :event, required: true
  prop has_changes, :boolean, required: true
  prop is_force_push, :boolean, default: false
  prop latest_published_publication, :any, required: true
  prop project, :struct, required: true
  prop publish_active, :event, required: true
  prop push_affected, :map, required: true
  prop version_change, :tuple, required: true

  def render(assigns) do
    ~F"""
      <div class="my-4 border-t pt-3">
        <Form for={@changeset} submit={@publish_active}>

          {#if @has_changes && @active_publication_changes}
            <h5>Versioning Details</h5>
            <p>The version number is automatically determined by the nature of the changes.</p>
            {#case @version_change}
              {#match {change_type, _} when change_type == :major or change_type == :minor}
                <div class="py-2">
                  <ul class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white">
                    <Field name={:publish_type}>
                      <li class="px-6 py-2 border-b border-gray-200 dark:border-gray-700 w-full rounded-t-lg">
                        <div class="flex flex-row p-2">
                          <div class="w-10 py-3 pr-2">
                            {#if change_type == :major}
                              <i class="fa-solid fa-arrow-right fa-xl text-blue-500"></i>
                            {/if}
                          </div>
                          <div class="flex-1">
                            <p>Major
                              {#case {@version_change, @latest_published_publication}}
                                {#match {{:major, {edition, major, minor}}, %{edition: current_edition, major: current_major, minor: current_minor}}}
                                  <small class="ml-1">
                                    {Utils.render_version(current_edition, current_major, current_minor)}
                                    <i class="fas fa-arrow-right mx-2"></i>
                                    {Utils.render_version(edition, major, minor)}
                                  </small>
                                {#match _}
                              {/case}
                            </p>
                            <small>Changes alter the structure of materials such as additions and deletions.</small>
                          </div>
                        </div>
                      </li>

                      <li class="px-6 py-2 w-full rounded-t-lg">
                        <div class="flex flex-row p-2">
                          <div class="w-10 py-3 pr-2">
                            {#if change_type == :minor}
                              <i class="fa-solid fa-arrow-right fa-xl text-blue-500"></i>
                            {/if}
                          </div>
                          <div class="flex-1">
                            <p>Minor
                              {#case {@version_change, @latest_published_publication}}
                                {#match {{:minor, {edition, major, minor}}, %{edition: current_edition, major: current_major, minor: current_minor}}}
                                  <small class="ml-1">
                                    {Utils.render_version(current_edition, current_major, current_minor)}
                                    <i class="fas fa-arrow-right mx-2"></i>
                                    {Utils.render_version(edition, major, minor)}
                                  </small>
                                {#match _}
                              {/case}
                            </p>
                            <small>Changes include small portions of reworked materials, grammar and spelling fixes.</small>
                          </div>
                        </div>
                      </li>
                    </Field>
                  </ul>
                </div>
              {#match {:no_changes, _}}
            {/case}
            <Field name={:description} class="form-group">
              <TextArea class="form-control" rows="3" opts={placeholder: "Enter a short description of these changes...", required: true} />
            </Field>
          {#else}
            {#if is_nil(@active_publication_changes)}
              <Field name={:description} class="form-group">
                <HiddenInput value="Initial publish" />
              </Field>
            {/if}
          {/if}

          <div class="form-group">
            <Field name={:active_publication_id}>
              <HiddenInput value={@active_publication.id} />
            </Field>
            <button type="submit" id="button-publish" class="btn btn-primary" disabled:!{@has_changes}, phx_disable_with="Publishing...">Publish</button>
            {#case @version_change}
              {#match {:no_changes, _}}

              {#match {_, {edition, major, minor}}}
                <span class="ml-2">{Utils.render_version(edition, major, minor)}</span>

              {#match _}
            {/case}
          </div>

          {#if @active_publication_changes}
            <div class="my-3">
              <Field name={:auto_push_update}>
                <Checkbox click={@force_push} value={@is_force_push}/>
                <Label>Automatically push this publication update to all products and sections</Label>
              </Field>
            </div>
          {/if}
          {#if @is_force_push}
            <div class="alert alert-warning" role="alert">
              {#if @push_affected.section_count > 0 or @push_affected.product_count > 0}
                <h6>This force push update will affect:</h6>
                <ul class="mb-0">
                  <li>{@push_affected.section_count} course section(s)</li>
                  <li>{@push_affected.product_count} product(s)</li>
                </ul>
              {#else}
                This force push update will not affect any product or course section.
              {/if}
            </div>
          {/if}

        </Form>
      </div>
    """
  end
end
