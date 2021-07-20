import AccordionTemplate from '../custom/AccordionTemplate';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';

const lessonSchema = {
  type: 'object',
  properties: {
    Properties: {
      type: 'object',
      title: ' Properties',
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
                'LEGACY',
              ],
            },
            customCssUrl: {
              type: 'string',
              title: 'Custom CSS URL',
            },
          },
        },
        FinishPanel: {
          type: 'object',
          properties: {
            logoutMessage: {
              title: 'Message',
              type: 'string',
              format: 'textarea',
            },
            logoutPanelImageURL: {
              type: 'string',
              title: 'Background URL',
            },
          },
        },
        enableHistory: {
          title: 'Enable History',
          type: 'boolean',
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
    },
    CustomLogic: {
      type: 'object',
      title: 'Custom Logic',
      properties: {
        variables: {
          type: 'string',
          title: 'Variables',
          format: 'textarea',
        },
        customScript: {
          type: 'string',
          title: 'Custom Script',
          format: 'textarea',
        },
      },
    },
  },
};

export const lessonUiSchema = {
  Properties: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
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
    FinishPanel: {
      'ui:ObjectFieldTemplate': CustomFieldTemplate,
      'ui:title': 'Finish Panel',
    },
    ScoreOverview: {
      'ui:ObjectFieldTemplate': CustomFieldTemplate,
      'ui:title': 'Score Overview',
    },
  },
  CustomLogic: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
  },
};

// we don't have the actual theme urls yet,
// they will likely come from somehwere else
const themeMap: { [key: string]: string } = {
  'url to new theme': 'Light Responsive',
  'default': 'LEGACY',
};

export const transformModelToSchema = (model: any) => {
  const [themeUrl, customCssUrl] = model.additionalStylesheets;
  const theme = themeMap[themeUrl] || 'LEGACY';

  return {
    Properties: {
      Size: { width: model.custom.defaultScreenWidth, height: model.custom.defaultScreenHeight },
      Appearance: {
        theme,
        customCssUrl,
      },
      ScoreOverview: {
        enableLessonMax: model.custom.enableLessonMax,
        lessonMax: model.custom.lessonMax,
      },
      FinishPanel: {
        logoutMessage: model.custom.logoutMessage,
        logoutPanelImageURL: model.custom.logoutPanelImageURL,
      },
      title: model.title,
      customCSS: model.customCss,
      enableHistory: model.custom.allowNavigation || model.custom.enableHistory || false,
    },
    CustomLogic: {
      variables: JSON.stringify(model.custom.variables),
      customScript: model.customScript,
    },
  };
};

export const transformSchemaToModel = (schema: any) => {
  /* console.log('LESSON SCHEMA -> MODEL', schema); */
  const themeUrl =
    Object.keys(themeMap).find((key) => themeMap[key] === schema.Properties.Appearance.theme) ||
    null;

  const additionalStylesheets = [themeUrl, schema.Properties.Appearance.customCssUrl];

  let variables = [];
  try {
    variables = JSON.parse(schema.CustomLogic.variables);
  } catch (e) {
    console.warn('could not parse variables', e);
  }

  return {
    custom: {
      defaultScreenWidth: schema.Properties.Size.width,
      defaultScreenHeight: schema.Properties.Size.height,
      enableLessonMax: schema.Properties.ScoreOverview.enableLessonMax,
      lessonMax: schema.Properties.ScoreOverview.lessonMax,
      enableHistory: schema.Properties.enableHistory,
      allowNavigation: schema.Properties.enableHistory,
      variables,
      logoutMessage: schema.Properties.FinishPanel.logoutMessage,
      logoutPanelImageURL: schema.Properties.FinishPanel.logoutPanelImageURL,
    },
    additionalStylesheets,
    title: schema.Properties.title,
    customCss: schema.Properties.customCSS,
    customScript: schema.CustomLogic.customScript,
  };
};

export default lessonSchema;
