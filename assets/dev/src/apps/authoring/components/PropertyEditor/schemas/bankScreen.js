import chroma from 'chroma-js';
import ColorPickerWidget from '../custom/ColorPickerWidget';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';
const BankPropsSchema = {
    type: 'object',
    properties: {
        title: {
            type: 'string',
            title: 'Title',
        },
        Size: {
            type: 'object',
            title: 'Dimensions',
            properties: {
                width: { type: 'number' },
                height: { type: 'number' },
            },
        },
        palette: {
            type: 'object',
            properties: {
                backgroundColor: { type: 'string', title: 'Background Color' },
                borderColor: { type: 'string', title: 'Border Color' },
                borderRadius: { type: 'string', title: 'Border Radius' },
                borderStyle: { type: 'string', title: 'Border Style' },
                borderWidth: { type: 'string', title: 'Border Width' },
            },
        },
        customCssClass: {
            title: 'Custom CSS Class',
            type: 'string',
        },
    },
};
export const BankPropsUiSchema = {
    Size: {
        'ui:ObjectFieldTemplate': CustomFieldTemplate,
        'ui:title': 'Dimensions',
        width: {
            classNames: 'col-6',
        },
        height: {
            classNames: 'col-6',
        },
    },
    palette: {
        'ui:ObjectFieldTemplate': CustomFieldTemplate,
        'ui:title': 'Palette',
        backgroundColor: {
            'ui:widget': ColorPickerWidget,
        },
        borderColor: {
            'ui:widget': ColorPickerWidget,
        },
        borderStyle: { classNames: 'col-6' },
        borderWidth: { classNames: 'col-6' },
    },
};
export const transformBankPropsModeltoSchema = (activity) => {
    var _a;
    if (activity) {
        const data = (_a = activity === null || activity === void 0 ? void 0 : activity.content) === null || _a === void 0 ? void 0 : _a.custom;
        if (!data) {
            console.warn('no custom??', { activity });
            // this might have happened from a previous version that trashed the lesson data
            // TODO: maybe look into validation / defaults
            return;
        }
        const schemaPalette = Object.assign(Object.assign({}, data.palette), { borderWidth: `${data.palette.lineThickness ? data.palette.lineThickness + 'px' : '1px'}`, borderRadius: '10px', borderStyle: 'solid', borderColor: `rgba(${data.palette.lineColor || data.palette.lineColor === 0
                ? chroma(data.palette.lineColor).rgb().join(',')
                : '255, 255, 255'},${data.palette.lineAlpha || '100'})`, backgroundColor: `rgba(${data.palette.fillColor || data.palette.fillColor === 0
                ? chroma(data.palette.fillColor).rgb().join(',')
                : '255, 255, 255'},${data.palette.fillAlpha || '100'})` });
        return Object.assign(Object.assign({}, data), { title: (activity === null || activity === void 0 ? void 0 : activity.title) || '', Size: { width: data.width, height: data.height }, palette: data.palette.useHtmlProps ? data.palette : schemaPalette });
    }
};
export const transformBankPropsSchematoModel = (schema) => {
    return {
        title: schema.title,
        width: schema.Size.width,
        height: schema.Size.height,
        customCssClass: schema.customCssClass,
        palette: Object.assign(Object.assign({}, schema.palette), { useHtmlProps: true }),
    };
};
export default BankPropsSchema;
//# sourceMappingURL=bankScreen.js.map