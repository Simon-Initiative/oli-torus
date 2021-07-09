import CustomFieldTemplate from '../custom/CustomFieldTemplate';

const lessonSchema = {
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
    Appearance: {
      type: 'object',
      title: 'Lesson Appearance',
      properties: {
        theme: {
          type: 'string',
          title: 'Lesson Theme',
          enum: [
            'Light Responsive',
            'Blue Responsive',
            'Dark Responsive',
            'Material Responsive',
            'Light',
            'Dark',
            'LEGACY',
          ],
        },
        customCssUrl: {
          type: 'string',
          title: 'Custom CSS URL',
        },
      },
    },
    ScoreOverview: {
      type: 'object',
      properties: {
        enableLessonMax: { type: 'boolean', title: 'Enable a Lesson Maximum' },
        lessonMax: { type: 'number', title: 'Lesson Max' },
      },
    },
    customCSS: {
      title: 'Custom CSS',
      type: 'string',
      description: 'block of css code to be injected into style tag',
      format: 'textarea',
    },
  },
};

export const lessonUiSchema = {
  Size: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Screen Size',
    width: {
      classNames: 'col-6',
    },
    height: {
      classNames: 'col-6',
    },
  },
  Appearance: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Lesson Appearance',
  },
  ScoreOverview: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Score Overview',
  },
};

// we don't have the actual theme urls yet,
// they will likely come from somehwere else
const themeMap: { [key: string]: string } = {
  'url to new theme': 'Light Responsive',
};

export const transformModelToSchema = (model: any) => {
  const [themeUrl, customCssUrl] = model.additionalStylesheets;
  const theme = themeMap[themeUrl] || 'LEGACY';

  return {
    Size: { width: model.custom.defaultScreenWidth, height: model.custom.defaultScreenHeight },
    Appearance: {
      theme,
      customCssUrl,
    },
    ScoreOverview: {
      enableLessonMax: model.custom.enableLessonMax,
      lessonMax: model.custom.lessonMax,
    },
    title: model.title,
    customCSS: model.customCss,
  };
};

export const transformSchemaToModel = (schema: any) => {
  const themeUrl = Object.keys(themeMap).find(key => themeMap[key] === schema.Appearance.theme) || null;

  const additionalStylesheets = [themeUrl, schema.Appearance.customCssUrl];

  return {
    custom: {
      defaultScreenWidth: schema.Size.width,
      defaultScreenHeight: schema.Size.height,
      enableLessonMax: schema.ScoreOverview.enableLessonMax,
      lessonMax: schema.ScoreOverview.lessonMax,
    },
    additionalStylesheets,
    title: schema.title,
    customCss: schema.customCSS,
  };
};

export default lessonSchema;
