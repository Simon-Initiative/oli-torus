function format_description(description: string) {
  const MAX_TEXT_LENGTH = 16;
  if (description && description.length > MAX_TEXT_LENGTH) {
    return ': ' + description.substr(0, MAX_TEXT_LENGTH) + '...'
  } else if (description) {
    return ': ' + description;
  }
  else {
    return '';
  }
}

export const ProjectsTypeahead = {
  mounted() {
    const $input = $('input.project-name.typeahead') as any;

    let cbHandlerInitialized = false;
    $input.typeahead({
      source: (query: string, cb: any) => {
        if (!cbHandlerInitialized) {
          this.handleEvent('projects', ({ projects }: any) => cb(projects));
          cbHandlerInitialized = true;
        }

        this.pushEvent('search', { search: query });
      },
      matcher: () => true,
      displayText: (item: any) =>
        `${item.title} v${item.version} (${item.slug})${format_description(item.description)}`,
      autoSelect: true,
      changeInputOnMove: false,
      afterSelect(sel: any) {
        $('input#section_name').val(sel.title);
        $('input#section_project_slug').val(sel.slug);
        $('input#section_title').val(sel.title);

        setTimeout(() => {
          $('input.title').focus().select();
        });
      },
    });
  },
};
