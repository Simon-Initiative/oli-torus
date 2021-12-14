export const initCommands = (model, setInputType) => {
    const makeCommand = (description, type) => ({
        type: 'CommandDesc',
        icon: () => '',
        description: () => description,
        active: () => model.inputType === type,
        command: {
            execute: (_context, _editor, _params) => {
                model.inputType !== type && setInputType(model.id, type);
            },
            precondition: () => true,
        },
    });
    return [
        [makeCommand('Dropdown', 'dropdown')],
        [makeCommand('Text', 'text')],
        [makeCommand('Number', 'numeric')],
    ];
};
//# sourceMappingURL=commands.jsx.map