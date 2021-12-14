import { CapiVariableTypes } from '../../../adaptivity/capi';
export const schema = {
    cssClasses: {
        title: 'CSS Classes',
        type: 'string',
    },
    customCss: {
        title: 'Custom CSS',
        type: 'string',
    },
    fontSize: {
        title: 'Font Size',
        type: 'number',
        default: 12,
    },
    showHints: {
        title: 'Show Hints',
        type: 'boolean',
        default: false,
        options: {
            hidden: true,
        },
    },
    enabled: {
        title: 'Enabled',
        type: 'boolean',
        default: true,
    },
    alternateCorrectDelimiter: {
        type: 'string',
    },
    showCorrect: {
        title: 'Show Correct',
        type: 'boolean',
        description: 'specifies whether to show the correct answers',
        default: false,
    },
    showSolution: {
        title: 'Show Solution',
        type: 'boolean',
        default: false,
        options: {
            hidden: true,
        },
    },
    formValidation: {
        title: 'Form Validation',
        type: 'boolean',
        default: false,
        options: {
            hidden: true,
        },
    },
    showValidation: {
        title: 'Show Validation',
        type: 'boolean',
        default: false,
        options: {
            hidden: true,
        },
    },
    screenReaderLanguage: {
        title: 'Screen Reader Language',
        type: 'string',
        enum: [
            'Arabic',
            'English',
            'French',
            'Italian',
            'Japanese',
            'Portuguese',
            'Russian',
            'Spanish',
        ],
        default: 'English',
    },
    caseSensitiveAnswers: {
        title: 'Case Sensitive Answers',
        type: 'boolean',
        default: false,
    },
};
export const uiSchema = {};
export const adaptivitySchema = ({ currentModel }) => {
    var _a;
    const adaptivitySchema = {};
    const elementData = (_a = currentModel === null || currentModel === void 0 ? void 0 : currentModel.custom) === null || _a === void 0 ? void 0 : _a.elements;
    adaptivitySchema.attempted = CapiVariableTypes.BOOLEAN;
    adaptivitySchema.correct = CapiVariableTypes.BOOLEAN;
    adaptivitySchema.customCss = CapiVariableTypes.STRING;
    adaptivitySchema.customCssClass = CapiVariableTypes.STRING;
    adaptivitySchema.enabled = CapiVariableTypes.BOOLEAN;
    adaptivitySchema.showCorrect = CapiVariableTypes.BOOLEAN;
    adaptivitySchema.showHints = CapiVariableTypes.BOOLEAN;
    if (elementData.length > 0) {
        elementData.forEach((element, index) => {
            adaptivitySchema[`Input ${index + 1}.Value`] = CapiVariableTypes.STRING;
            adaptivitySchema[`Input ${index + 1}.Correct`] = CapiVariableTypes.BOOLEAN;
            adaptivitySchema[`Input ${index + 1}.Alternate Correct`] = CapiVariableTypes.STRING;
        });
    }
    return adaptivitySchema;
};
export const createSchema = () => ({
    cssClasses: '',
    customCss: '',
    showHints: false,
    showCorrect: false,
    alternateCorrectDelimiter: '',
    caseSensitiveAnswers: false,
});
//# sourceMappingURL=schema.js.map