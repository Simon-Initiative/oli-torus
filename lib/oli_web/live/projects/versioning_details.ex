defmodule OliWeb.Projects.VersioningDetails do
  use Surface.Component

  alias Surface.Components.{Form}

  alias Surface.Components.Form.{
    Checkbox,
    Field,
    HiddenInput,
    Label,
    RadioButton,
    TextArea
  }

  prop active_publication, :struct, required: true
  prop active_publication_changes, :map, required: true
  prop changeset, :any, required: true
  prop force_push, :event, required: true
  prop has_changes, :boolean, required: true
  prop is_force_push, :boolean, default: false
  prop latest_published_publication, :struct, required: true
  prop product_count, :integer, default: 0
  prop project, :struct, required: true
  prop publish_active, :event, required: true
  prop section_count, :integer, default: 0
  prop version_change, :tuple, required: true

  def render(assigns) do
    ~F"""
      <div class="my-4 border-top pt-3">
        <Form for={@changeset} submit={@publish_active}>

          {#if @has_changes && @active_publication_changes}
            <h5>Versioning Details</h5>
            <h6 class="pb-3">The version number is automatically determined by the nature of the changes.</h6>
            {#case @version_change}
              {#match {change_type, _}}
                <div class="form-check form-switch">
                  <Field name={:publish_type}>
                    <div class="form-group" style="pointer-events: none">
                      <RadioButton class="form-check-input" checked={change_type == :major} value={:major}/>
                      <Label class="form-check-label">
                        <p>Major
                          {#case {@version_change, @latest_published_publication}}
                            {#match {{:major, {edition, major, minor}}, %{edition: current_edition, major: current_major, minor: current_minor}}}
                            <small class="ml-1">{render_version(current_edition, current_major, current_minor)}<i class="fa fa-arrow-right mx-2"></i>{render_version(edition, major, minor)}</small>
                            {#match _}
                          {/case}
                        </p>
                        <small>Changes alter the structure of materials such as additions and deletions.</small>
                      </Label>
                    </div>

                    <div class="form-group" style="pointer-events: none">
                      <RadioButton class="form-check-input" checked={change_type == :minor} value={:minor}/>
                      <Label class="form-check-label">
                        <p>Minor
                          {#case {@version_change, @latest_published_publication}}
                            {#match {{:minor, {edition, major, minor}}, %{edition: current_edition, major: current_major, minor: current_minor}}}
                            <small class="ml-1">{render_version(current_edition, current_major, current_minor)}<i class="fa fa-arrow-right mx-1"></i>{render_version(edition, major, minor)}</small>
                            {#match _}
                          {/case}
                        </p>
                        <small>Changes include small portions of reworked materials, grammar and spelling fixes.</small>
                      </Label>
                    </div>
                  </Field>
                </div>
            {/case}
            <Field name={:description} class="form-group">
              <TextArea class="form-control" rows="3" opts={placeholder: "Enter a short description of these changes..."} />
            </Field>
          {#else}
            {#if is_nil(@active_publication_changes)}
              <HiddenInput value="Initial publish" />
            {/if}
          {/if}

          <Field name={:active_publication_id}>
            <HiddenInput value={@active_publication.id} />
          </Field>
          <button type="submit" id="button-publish" class="btn btn-sm btn-primary" phx_disable_with="Publishing...">Publish</button>
          <div class="my-3">
            <Field name={:auto_push_update}>
              <Checkbox click={@force_push} value={@is_force_push}/>
              <Label>Automatically push this publication update to all products and sections</Label>
            </Field>
          </div>
          {#if @is_force_push}
            <div class="alert alert-warning" role="alert">
              {#if @section_count > 0 or @product_count > 0}
                This force push update will affect
                {render_section_count(assigns, @section_count)}
                {render_product_count(assigns, @product_count, @section_count)}
              {#else}
                This force push update will not affect any product or course section.
              {/if}
            </div>
          {/if}

        </Form>
      </div>
    """
  end

  defp render_product_count(assigns, product_count, section_count) do
    ~F"""
      {#case product_count}
        {#match 0}

        {#match 1}
          {#if section_count > 0}and{/if}<strong> {product_count} product</strong>

        {#match _}
          {#if section_count > 0}and{/if}<strong> {product_count} products</strong>
      {/case}
    """
  end

  defp render_section_count(assigns, section_count) do
    ~F"""
      {#case section_count}
        {#match 0}

        {#match 1}
          <strong> {section_count} course section</strong>

        {#match _}
          <strong> {section_count} course sections</strong>
      {/case}
    """
  end

  defp render_version(edition, major, minor) do
    "v#{edition}.#{major}.#{minor}"
  end
end
