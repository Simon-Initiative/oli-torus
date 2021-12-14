import { CapiVariableTypes } from '../../../adaptivity/capi';
import CustomFieldTemplate from 'apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
export const schema = {
    customCssClass: {
        title: 'Custom CSS Class',
        type: 'string',
    },
    src: {
        title: 'Source',
        type: 'string',
    },
    alt: {
        title: 'Alternate Text',
        type: 'string',
    },
    triggerCheck: {
        title: 'Trigger Check',
        type: 'boolean',
        description: 'if set to true then once audio is played till end, it will fire a check event',
        default: false,
    },
    autoPlay: {
        title: 'Autoplay',
        type: 'boolean',
        description: 'if set to true then video player will play automatically',
        default: false,
    },
    startTime: {
        title: 'Start time(secs)',
        type: 'number',
        description: 'specifies the start time of the video',
        default: 0,
    },
    endTime: {
        title: 'End time(secs)',
        type: 'number',
        description: 'specifies the end time of the video',
        default: 0,
    },
    enableReplay: {
        title: 'Enable Replay',
        type: 'boolean',
        description: 'specifies whether user can replay the video once its played',
        default: true,
    },
    subtitles: {
        title: 'Subtitles',
        type: 'object',
        properties: {
            default: { type: 'boolean', title: 'Default' },
            language: { type: 'string', title: 'Language' },
            src: { type: 'string', title: 'Source' },
        },
        required: ['src', 'language'],
    },
};
export const uiSchema = {
    subtitles: {
        'ui:title': 'Subtitles',
        'ui:ObjectFieldTemplate': CustomFieldTemplate,
    },
};
export const adaptivitySchema = {
    hasStarted: CapiVariableTypes.BOOLEAN,
    autoPlay: CapiVariableTypes.BOOLEAN,
    currentTime: CapiVariableTypes.STRING,
    duration: CapiVariableTypes.STRING,
    endTime: CapiVariableTypes.STRING,
    exposureInSeconds: CapiVariableTypes.NUMBER,
    exposurePercentage: CapiVariableTypes.NUMBER,
    hasCompleted: CapiVariableTypes.BOOLEAN,
    startTime: CapiVariableTypes.STRING,
    state: CapiVariableTypes.STRING,
    totalSecondsWatched: CapiVariableTypes.STRING,
    enableReplay: CapiVariableTypes.BOOLEAN,
};
export const createSchema = () => ({
    enabled: true,
    enableReplay: true,
    autoPlay: false,
    startTime: 0,
    endTime: 0,
    src: '',
    alt: '',
    customCssClass: '',
    triggerCheck: false,
});
//# sourceMappingURL=schema.js.map