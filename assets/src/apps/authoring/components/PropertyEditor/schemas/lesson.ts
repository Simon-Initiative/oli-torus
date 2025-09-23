import { UiSchema } from '@rjsf/core';
import { JSONSchema7 } from 'json-schema';
import AccordionTemplate from '../custom/AccordionTemplate';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';
import VariableEditor, { FieldTemplate, ObjectFieldTemplate } from '../custom/VariableEditor';

const lessonSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    Properties: {
      type: 'object',
      title: ' Properties',
      properties: {
        title: {
          type: 'string',
          title: 'Title',
          readOnly: true,
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
              anyOf: [
                {
                  type: 'string',
                  title: 'Default Theme',
                  enum: [
                    '/css/delivery_adaptive_themes_default_light.css',
                    '/css/delivery_adaptive_themes_flowchart.css',
                  ],
                  default: '/css/delivery_adaptive_themes_default_light.css',
                },
                { type: 'string', title: 'Custom Theme' },
              ],
            },
            customCssUrl: {
              type: 'string',
              title: 'Custom CSS URL',
            },
            responsiveLayout: {
              type: 'boolean',
              title: 'Responsive Layout',
              default: false,
            },
            backgroundImageURL: {
              type: 'string',
              title: 'Background Image URL',
            },
            backgroundImageScaleContent: {
              type: 'boolean',
              title: 'Scale Background Image to Fit',
            },
            displayApplicationChrome: {
              type: 'boolean',
              title: 'Display Torus Navigation',
              default: 'false',
            },
            darkModeSetting: {
              type: 'boolean',
              title: 'Enable Dark Mode',
              default: 'false',
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
        displayRefreshWarningPopup: {
          type: 'boolean',
          title: 'Refresh warning popup',
          default: 'true',
        },
        customCSS: {
          title: 'Custom CSS',
          type: 'string',
          description: 'block of css code to be injected into style tag',
          format: 'textarea',
        },
        InterfaceSettings: {
          type: 'object',
          title: 'Interface Settings',
          properties: {
            grid: {
              type: 'boolean',
              title: '10px Grid',
              default: 'false',
            },
            centerpoint: {
              type: 'boolean',
              title: 'Centerpoint',
              default: 'false',
            },
            columnGuides: {
              type: 'boolean',
              title: 'Column Guides',
              default: 'false',
            },
            rowGuides: {
              type: 'boolean',
              title: 'Row Guides',
              default: 'false',
            },
          },
        },
      },
    },
    CustomLogic: {
      type: 'object',
      title: 'Custom Logic',
      properties: {
        variables: {
          type: 'array',
          title: 'Variables',
          items: {
            type: 'object',
            properties: {
              name: {
                type: 'string',
                title: 'Name',
              },
              expression: {
                type: 'string',
                title: 'Expression',
              },
            },
          },
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

export const simpleLessonSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    Properties: {
      type: 'object',
      title: ' Properties',
      properties: {
        title: {
          type: 'string',
          title: 'Title',
          readOnly: true,
        },

        Appearance: {
          type: 'object',
          properties: {
            displayApplicationChrome: {
              type: 'boolean',
              title: 'Display Torus Navigation',
              default: 'false',
            },
            darkModeSetting: {
              type: 'boolean',
              title: 'Enable Dark Mode',
              default: 'false',
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
          },
        },
        enableHistory: {
          title: 'Enable History',
          type: 'boolean',
        },
        displayRefreshWarningPopup: {
          type: 'boolean',
          title: 'Refresh warning popup',
          default: 'true',
        },
        InterfaceSettings: {
          type: 'object',
          title: 'Interface Settings',
          properties: {
            grid: {
              type: 'boolean',
              title: '10px Grid',
              default: 'false',
            },
            centerpoint: {
              type: 'boolean',
              title: 'Centerpoint',
              default: 'false',
            },
            columnGuides: {
              type: 'boolean',
              title: 'Column Guides',
              default: 'false',
            },
            rowGuides: {
              type: 'boolean',
              title: 'Row Guides',
              default: 'false',
            },
          },
        },
      },
    },
  },
};

export const simpleLessonUiSchema: UiSchema = {
  Properties: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    FinishPanel: {
      'ui:ObjectFieldTemplate': CustomFieldTemplate,
      'ui:title': 'Finish Panel',
    },
    InterfaceSettings: {
      classNames: 'col-span-12 InterfaceSettings',
    },
  },
};

export const lessonUiSchema: UiSchema = {
  Properties: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    Size: {
      'ui:ObjectFieldTemplate': CustomFieldTemplate,
      'ui:title': 'Screen Size',
      width: {
        classNames: 'col-span-6',
      },
      height: {
        classNames: 'col-span-6',
      },
    },
    Appearance: {
      'ui:ObjectFieldTemplate': CustomFieldTemplate,
      'ui:title': 'Lesson Appearance',
      backgroundImageURL: {
        'ui:widget': 'TorusImageBrowser',
      },
      responsiveLayout: {
        'ui:title': 'Enable Responsive Layout',
        'ui:description': 'Use responsive layout for parts instead of fixed positioning',
        classNames: 'col-span-12',
      },
    },
    FinishPanel: {
      'ui:ObjectFieldTemplate': CustomFieldTemplate,
      'ui:title': 'Finish Panel',
    },
    InterfaceSettings: {
      classNames: 'col-span-12 InterfaceSettings',
    },
  },
  CustomLogic: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    variables: {
      'ui:ArrayFieldTemplate': VariableEditor,
      items: {
        'ui:ObjectFieldTemplate': ObjectFieldTemplate,
        name: {
          'ui:FieldTemplate': FieldTemplate,
        },
        expression: {
          'ui:FieldTemplate': FieldTemplate,
        },
      },
    },
  },
};

// we don't have the actual theme urls yet,
// they will likely come from somehwere else
// const themeMap: { [key: string]: string } = {
//   'url to new theme': 'Light Responsive',
//   'default': 'LEGACY',
// };

export const transformModelToSchema = (model: any) => {
  const [themeUrl, customCssUrl] = model.additionalStylesheets;
  console.log('LESSON MODEL -> SCHEMA', model, { model, themeUrl, customCssUrl });
  return {
    Properties: {
      Size: { width: model.custom.defaultScreenWidth, height: model.custom.defaultScreenHeight },
      Appearance: {
        theme: themeUrl,
        customCssUrl,
        backgroundImageURL: model.custom.backgroundImageURL,
        backgroundImageScaleContent: model.custom.backgroundImageScaleContent,
        displayApplicationChrome: model.displayApplicationChrome,
        darkModeSetting: model.custom.darkModeSetting || false,
        responsiveLayout: model.custom.responsiveLayout || false,
      },
      FinishPanel: {
        logoutMessage: model.custom.logoutMessage,
        logoutPanelImageURL: model.custom.logoutPanelImageURL,
      },
      title: model.title,
      customCSS: model.customCss,
      enableHistory: model.custom.allowNavigation || model.custom.enableHistory || false,
      displayRefreshWarningPopup: model.custom.displayRefreshWarningPopup ?? true,
      InterfaceSettings: {
        grid: model.custom.grid || false,
        centerpoint: model.custom.centerpoint || false,
        columnGuides: model.custom.columnGuides || false,
        rowGuides: model.custom.rowGuides || false,
      },
    },
    CustomLogic: {
      variables: model.custom.variables,
      customScript: model.customScript,
    },
  };
};

export const transformSchemaToModel = (schema: any) => {
  console.log('LESSON SCHEMA -> MODEL', schema);

  const additionalStylesheets = [
    schema.Properties.Appearance.theme,
    schema.Properties.Appearance.customCssUrl,
  ].filter((url) => url);

  let variables = [];
  try {
    variables = schema.CustomLogic.variables;
  } catch (e) {
    // console.warn('could not parse variables', e);
    // most likely just empty string
  }

  return {
    custom: {
      defaultScreenWidth: schema.Properties.Size.width,
      defaultScreenHeight: schema.Properties.Size.height,
      enableHistory: schema.Properties.enableHistory,
      displayRefreshWarningPopup: schema.Properties.displayRefreshWarningPopup,
      variables,
      logoutMessage: schema.Properties.FinishPanel.logoutMessage,
      logoutPanelImageURL: schema.Properties.FinishPanel.logoutPanelImageURL,
      backgroundImageURL: schema.Properties.Appearance.backgroundImageURL,
      backgroundImageScaleContent: schema.Properties.Appearance.backgroundImageScaleContent,
      darkModeSetting: schema.Properties.Appearance.darkModeSetting,
      responsiveLayout: schema.Properties.Appearance.responsiveLayout,
      grid: schema.Properties.InterfaceSettings.grid,
      centerpoint: schema.Properties.InterfaceSettings.centerpoint,
      columnGuides: schema.Properties.InterfaceSettings.columnGuides,
      rowGuides: schema.Properties.InterfaceSettings.rowGuides,
    },
    displayApplicationChrome: schema.Properties.Appearance.displayApplicationChrome,
    additionalStylesheets,
    title: schema.Properties.title,
    customCss: schema.Properties.customCSS || '',
    customScript: schema.CustomLogic.customScript || '',
  };
};

export default lessonSchema;
