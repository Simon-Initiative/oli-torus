import { CapiVariableTypes } from '../../../adaptivity/capi';
export const schema = {
    overrideHeight: {
        title: 'Override Height',
        type: 'boolean',
        default: false,
        description: 'enable to use the value provided by the height field',
    },
    customCssClass: {
        title: 'Custom CSS Class',
        type: 'string',
    },
    fontSize: {
        title: 'Font Size',
        type: 'number',
        default: 12,
    },
    layoutType: {
        title: 'Layout',
        type: 'string',
        description: 'specifies the layout type for options',
        enum: ['horizontalLayout', 'verticalLayout'],
        default: 'verticalLayout',
    },
    verticalGap: {
        title: 'Vertical Gap',
        type: 'number',
    },
    multipleSelection: {
        title: 'Multiple Selection',
        type: 'boolean',
        default: false,
        description: 'specifies whether multiple items can be selected',
    },
    randomize: {
        title: 'Randomize',
        type: 'boolean',
        description: 'specifies whether to randomize the MCQ items',
        default: false,
    },
    enabled: {
        title: 'Enabled',
        type: 'boolean',
        description: 'specifies whether MCQ is enabled',
        default: true,
    },
};
export const adaptivitySchema = {
    enabled: CapiVariableTypes.BOOLEAN,
    randomize: CapiVariableTypes.BOOLEAN,
    numberOfSelectedChoices: CapiVariableTypes.NUMBER,
    selectedChoice: CapiVariableTypes.NUMBER,
    selectedChoiceText: CapiVariableTypes.STRING,
    selectedChoices: CapiVariableTypes.ARRAY,
    selectedChoicesText: CapiVariableTypes.ARRAY,
};
export const uiSchema = {};
export const getCapabilities = () => ({
    configure: true,
});
export const createSchema = () => {
    const createSimpleOption = (index, score = 1) => ({
        scoreValue: score,
        nodes: [
            {
                tag: 'p',
                children: [
                    {
                        tag: 'span',
                        style: {},
                        children: [
                            {
                                tag: 'text',
                                text: `Option ${index}`,
                                children: [],
                            },
                        ],
                    },
                ],
            },
        ],
    });
    return {
        overrideHeight: false,
        customCssClass: '',
        layoutType: 'verticalLayout',
        verticalGap: 0,
        maxManualGrade: 0,
        showOnAnswersReport: false,
        requireManualGrading: false,
        showLabel: true,
        multipleSelection: false,
        randomize: false,
        showNumbering: false,
        enabled: true,
        mcqItems: [1, 2, 3].map(createSimpleOption),
    };
};
//# sourceMappingURL=schema.js.map