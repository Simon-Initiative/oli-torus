import CustomFieldTemplate from '../custom/CustomFieldTemplate';
const lessonSchema = {
  type: 'object',
  properties: {
    Size: {
      type: "object",
      title: "Dimensions",
      properties: {
        width: { type: 'number' },
        height: { type: 'number' }
      }
    },
    Appearance: {
      type: 'object',
      title: 'Lesson Appearance',
      properties: {
        theme: {
          type:'string',
          title: 'Lesson Theme',
          enum: [
            'Light Responsive', 'Blue Responsive','Dark Responsive','Material Responsive', 'Light', 'Dark'
          ]
        },
        customCssUrl: {
          type:'string',
          title: 'Custom CSS URL'
        }
      }
    },
    ScoreOverview: {
      type: "object",
      properties: {
        enableLessonMax: { type: 'boolean', title: 'Enable a Lesson Maximum' },
        lessonMax: { type: 'number', title:'Lesson Max' }
      }
    },
    title: {
      type: 'string',
      title: 'Title' ,
    },
    customCSS: {
      title: 'Custom CSS',
      type: 'string',
      description: 'block of css code to be injected into style tag',
      format: 'textarea',
    }
  },
};

export const lessonUiSchema = {
  Size: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Screen Size',
    width: {
      classNames: 'col-6'
    },
    height: {
      classNames: 'col-6'
    }
  },
  Appearance: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Lesson Appearance'
  },
  ScoreOverview: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Score Overview'
  }
};


export default lessonSchema;
