function format_description(description) {
    const MAX_TEXT_LENGTH = 16;
    if (description && description.length > MAX_TEXT_LENGTH) {
        return ': ' + description.substr(0, MAX_TEXT_LENGTH) + '...';
    }
    if (description) {
        return ': ' + description;
    }
    return '';
}
export const ProjectsTypeahead = {
    mounted() {
        const $input = $('input.project-name.typeahead');
        let cbHandlerInitialized = false;
        $input.typeahead({
            source: (query, cb) => {
                if (!cbHandlerInitialized) {
                    this.handleEvent('projects', ({ projects }) => cb(projects));
                    cbHandlerInitialized = true;
                }
                this.pushEvent('search', { search: query });
            },
            matcher: () => true,
            displayText: (item) => `${item.title} v${item.version} (${item.slug})${format_description(item.description)}`,
            autoSelect: true,
            changeInputOnMove: false,
            afterSelect(sel) {
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
//# sourceMappingURL=projects_typeahead.js.map