
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
      displayText: (item: any) => item.title,
      autoSelect: true,
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
