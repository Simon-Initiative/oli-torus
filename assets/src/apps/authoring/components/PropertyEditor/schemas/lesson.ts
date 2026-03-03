import { UiSchema } from '@rjsf/core';
import { JSONSchema7 } from 'json-schema';
import AccordionTemplate from '../custom/AccordionTemplate';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';
import { CUSTOM_THEME_DEFAULT } from '../custom/ThemeSelectorWidget';
import TooltipFieldTemplate from '../custom/TooltipFieldTemplate';
import VariableEditor, { FieldTemplate, ObjectFieldTemplate } from '../custom/VariableEditor';

const DEFAULT_THEME_URL = '/css/delivery_adaptive_themes_default_light.css';

const lessonSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    Properties: {
      type: 'object',
      title: 'Properties',
      properties: {
        title: {
          type: 'string',
          title: 'Title',
          readOnly: true,
        },
        Size: {
          type: 'object',
          title: 'Screen Size',
          properties: {
            width: { type: 'number' },
            height: { type: 'number' },
          },
        },
        responsiveLayout: {
          type: 'boolean',
          title: 'Enable Responsive Layout',
          description: 'Use responsive layout for parts instead of fixed positioning',
          default: false,
        },
      },
    },
    LessonAppearance: {
      type: 'object',
      title: 'Lesson Appearance',
      properties: {
        theme: {
          type: 'string',
          title: 'Theme',
          default: DEFAULT_THEME_URL,
        },
        customCssUrl: {
          type: 'string',
          title: 'Custom CSS URL',
        },
        darkModeSetting: {
          type: 'boolean',
          title: 'Enable Dark Mode',
          default: 'false',
        },
        backgroundImageURL: {
          type: 'string',
          title: 'Background Image URL',
        },
        backgroundImageScaleContent: {
          type: 'boolean',
          title: 'Scale Background Image to Fit',
        },
      },
    },
    NavigationBehavior: {
      type: 'object',
      title: 'Navigation & Behavior',
      properties: {
        displayApplicationChrome: {
          type: 'boolean',
          title: 'Display Torus Interface',
          default: 'false',
        },
        enableHistory: {
          title: 'Enable Lesson History',
          type: 'boolean',
        },
        displayRefreshWarningPopup: {
          type: 'boolean',
          title: 'Enable Refresh Warning Popup',
          default: 'true',
        },
        FinishPanel: {
          type: 'object',
          properties: {
            logoutMessage: {
              title: 'Finish Panel Message',
              type: 'string',
              format: 'textarea',
            },
            logoutPanelImageURL: {
              type: 'string',
              title: 'Finish Panel Background URL',
            },
          },
        },
      },
    },
    AuthorInterfaceTools: {
      type: 'object',
      title: 'Author Interface Tools',
      description: 'Grids and guides to help with formatting. These are never visible to students.',
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
    Advanced: {
      type: 'object',
      title: 'Advanced',
      properties: {
        variables: {
          type: 'array',
          title: 'Variables',
          items: {
            type: 'object',
            properties: {
              name: { type: 'string', title: 'Name' },
              expression: { type: 'string', title: 'Expression' },
            },
          },
        },
        customCSS: {
          title: 'Custom CSS',
          type: 'string',
          description: 'block of css code to be injected into style tag',
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

export const simpleLessonSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    Properties: {
      type: 'object',
      title: 'Properties',
      properties: {
        title: {
          type: 'string',
          title: 'Title',
          readOnly: true,
        },
      },
    },
    LessonAppearance: {
      type: 'object',
      title: 'Lesson Appearance',
      properties: {
        darkModeSetting: {
          type: 'boolean',
          title: 'Enable Dark Mode',
          default: 'false',
        },
      },
    },
    NavigationBehavior: {
      type: 'object',
      title: 'Navigation & Behavior',
      properties: {
        displayApplicationChrome: {
          type: 'boolean',
          title: 'Display Torus Interface',
          default: 'false',
        },
        FinishPanel: {
          type: 'object',
          properties: {
            logoutMessage: {
              title: 'Finish Panel Message',
              type: 'string',
              format: 'textarea',
            },
          },
        },
        enableHistory: {
          title: 'Enable Lesson History',
          type: 'boolean',
        },
        displayRefreshWarningPopup: {
          type: 'boolean',
          title: 'Enable Refresh Warning Popup',
          default: 'true',
        },
      },
    },
    AuthorInterfaceTools: {
      type: 'object',
      title: 'Author Interface Tools',
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
};

export const simpleLessonUiSchema: UiSchema = {
  Properties: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
  },
  LessonAppearance: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
  },
  NavigationBehavior: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    FinishPanel: {
      'ui:ObjectFieldTemplate': CustomFieldTemplate,
    },
  },
  AuthorInterfaceTools: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    grid: {
      classNames: 'col-span-12',
    },
    centerpoint: {
      classNames: 'col-span-12',
    },
    columnGuides: {
      classNames: 'col-span-12',
    },
    rowGuides: {
      classNames: 'col-span-12',
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
    responsiveLayout: {
      classNames: 'col-span-12',
      'ui:tooltip':
        'Automatically arranges components in full or half-width rows and adjusts layout to fit different screen sizes. When off, components must be positioned manually and do not resize.',
      'ui:FieldTemplate': TooltipFieldTemplate,
    },
  },
  LessonAppearance: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    theme: {
      'ui:widget': 'ThemeSelectorWidget',
    },
    darkModeSetting: {
      'ui:tooltip':
        'Allows the lesson to support both light and dark themes. Recommended only when using custom or external styles that include dark mode styling.',
      'ui:FieldTemplate': TooltipFieldTemplate,
    },
    backgroundImageURL: {
      'ui:widget': 'TorusImageBrowser',
    },
  },
  NavigationBehavior: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    displayApplicationChrome: {
      'ui:tooltip':
        'Displays the full Torus interface (header and course controls) around the lesson. When off (default), the lesson runs in standalone full-screen mode.',
      'ui:FieldTemplate': TooltipFieldTemplate,
    },
    enableHistory: {
      'ui:tooltip':
        'Allows students to revisit previously completed screens in read-only mode to review their responses. When off, students can only move forward through the lesson.',
      'ui:FieldTemplate': TooltipFieldTemplate,
    },
    displayRefreshWarningPopup: {
      'ui:tooltip':
        'Displays a warning if students refresh the page or try to leave the lesson before completing a screen or saving their answers.',
      'ui:FieldTemplate': TooltipFieldTemplate,
    },
    FinishPanel: {
      'ui:ObjectFieldTemplate': CustomFieldTemplate,
    },
  },
  AuthorInterfaceTools: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    grid: {
      classNames: 'col-span-12',
    },
    centerpoint: {
      classNames: 'col-span-12',
    },
    columnGuides: {
      classNames: 'col-span-12',
    },
    rowGuides: {
      classNames: 'col-span-12',
    },
  },
  Advanced: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    variables: {
      'ui:ArrayFieldTemplate': VariableEditor,
      items: {
        'ui:ObjectFieldTemplate': ObjectFieldTemplate,
        name: { 'ui:FieldTemplate': FieldTemplate },
        expression: { 'ui:FieldTemplate': FieldTemplate },
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
  const [themeUrl, customCssUrl] = model.additionalStylesheets || [];
  const isDefaultTheme = themeUrl === DEFAULT_THEME_URL || !themeUrl;
  const theme = isDefaultTheme ? DEFAULT_THEME_URL : themeUrl || CUSTOM_THEME_DEFAULT;
  const formCustomCssUrl = customCssUrl || '';

  return {
    Properties: {
      Size: { width: model.custom.defaultScreenWidth, height: model.custom.defaultScreenHeight },
      title: model.title,
      responsiveLayout: model.custom.responsiveLayout || false,
    },
    LessonAppearance: {
      theme,
      customCssUrl: formCustomCssUrl,
      darkModeSetting: model.custom.darkModeSetting || false,
      backgroundImageURL: model.custom.backgroundImageURL,
      backgroundImageScaleContent: model.custom.backgroundImageScaleContent,
    },
    NavigationBehavior: {
      displayApplicationChrome: model.displayApplicationChrome,
      enableHistory: model.custom.allowNavigation || model.custom.enableHistory || false,
      displayRefreshWarningPopup: model.custom.displayRefreshWarningPopup ?? true,
      FinishPanel: {
        logoutMessage: model.custom.logoutMessage,
        logoutPanelImageURL: model.custom.logoutPanelImageURL,
      },
    },
    AuthorInterfaceTools: {
      grid: model.custom.grid || false,
      centerpoint: model.custom.centerpoint || false,
      columnGuides: model.custom.columnGuides || false,
      rowGuides: model.custom.rowGuides || false,
    },
    Advanced: {
      variables: model.custom.variables,
      customCSS: model.customCss,
      customScript: model.customScript,
    },
  };
};

export const transformSchemaToModel = (schema: any) => {
  /* console.log('LESSON SCHEMA -> MODEL', schema); */

  const appearanceTheme = schema.LessonAppearance?.theme;
  const customCssUrl = schema.LessonAppearance?.customCssUrl;
  const additionalStylesheets =
    appearanceTheme === CUSTOM_THEME_DEFAULT
      ? [customCssUrl].filter(Boolean)
      : [appearanceTheme, customCssUrl].filter((url) => url && url !== CUSTOM_THEME_DEFAULT);

  const responsiveLayout = schema.Properties?.responsiveLayout;
  // When responsiveLayout is true, width is treated as maxWidth
  const width = responsiveLayout
    ? schema.Properties?.Size?.width || 1200 // Default to 1200px if not set
    : schema.Properties?.Size?.width;

  return {
    custom: {
      defaultScreenWidth: width,
      defaultScreenHeight: schema.Properties?.Size?.height,
      enableHistory: schema.NavigationBehavior?.enableHistory,
      displayRefreshWarningPopup: schema.NavigationBehavior?.displayRefreshWarningPopup,
      logoutMessage: schema.NavigationBehavior?.FinishPanel?.logoutMessage,
      logoutPanelImageURL: schema.NavigationBehavior?.FinishPanel?.logoutPanelImageURL,
      backgroundImageURL: schema.LessonAppearance?.backgroundImageURL,
      backgroundImageScaleContent: schema.LessonAppearance?.backgroundImageScaleContent,
      darkModeSetting: schema.LessonAppearance?.darkModeSetting,
      responsiveLayout,
      variables: schema.Advanced?.variables || [],
      grid: schema.AuthorInterfaceTools?.grid,
      centerpoint: schema.AuthorInterfaceTools?.centerpoint,
      columnGuides: schema.AuthorInterfaceTools?.columnGuides,
      rowGuides: schema.AuthorInterfaceTools?.rowGuides,
    },
    displayApplicationChrome: schema.NavigationBehavior?.displayApplicationChrome,
    additionalStylesheets,
    title: schema.Properties?.title,
    customCss: schema.Advanced?.customCSS || '',
    customScript: schema.Advanced?.customScript || '',
  };
};

export const getLessonSchema = (responsiveLayout: boolean): JSONSchema7 => {
  if (!responsiveLayout) {
    return lessonSchema;
  }

  // Create a new schema object with the modified width title
  const schema: JSONSchema7 = {
    ...lessonSchema,
    properties: {
      ...lessonSchema.properties,
      Properties: {
        ...(lessonSchema.properties as any).Properties,
        properties: {
          ...((lessonSchema.properties as any).Properties.properties || {}),
          Size: {
            ...((lessonSchema.properties as any).Properties.properties?.Size || {}),
            properties: {
              ...(((lessonSchema.properties as any).Properties.properties?.Size
                ?.properties as any) || {}),
              width: {
                ...(((
                  (lessonSchema.properties as any).Properties.properties?.Size?.properties as any
                )?.width as any) || {}),
                title: 'Max Width',
              },
            },
          },
        },
      },
    },
  };
  return schema;
};

export const getLessonUiSchema = (responsiveLayout: boolean): UiSchema => {
  if (!responsiveLayout) {
    return lessonUiSchema;
  }

  // Create a new UI schema object preserving all function references and structure
  // Only modify the width field title, keep everything else exactly as is
  const PropertiesSchema = lessonUiSchema.Properties as any;
  const uiSchema: UiSchema = {
    Properties: {
      ...PropertiesSchema,
      Size: {
        ...PropertiesSchema.Size,
        width: {
          ...PropertiesSchema.Size.width,
          title: 'Max Width',
        },
      },
    },
    LessonAppearance: lessonUiSchema.LessonAppearance,
    NavigationBehavior: lessonUiSchema.NavigationBehavior,
    AuthorInterfaceTools: lessonUiSchema.AuthorInterfaceTools,
    Advanced: lessonUiSchema.Advanced,
  };
  return uiSchema;
};

export default lessonSchema;
