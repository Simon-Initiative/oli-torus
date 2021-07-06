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
    defaultTextStyle: {
      type: 'string',
      title: 'Text Style',
      enum: ['title', 'heading', 'sub-heading','body-text','small-text','caption','code'],
      enumNames: ['Title', 'Heading', 'Sub-heading', 'Body Text', 'Small Text', 'Caption', 'Code']
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
        },
        headingStyleType: {
          type:'string',
          title: 'Lesson Title Style',
          enum: ['Title', 'Heading', 'Sub-heading']
        },
        renderAccessibleOrderedList: {
          type:'boolean',
          title: 'User accessible ordered lists'
        },
        showOptionsMenu: {
          type:'boolean',
          title: 'Show learner options menu'
        },
        enableLearningApps: {
          type:'boolean',
          title: 'Enable Learning Apps'
        },
        globalNumberFormat: {
          type:'string',
          title: 'Number Format',
          enum: ['Rounded Financial Format', 'none']
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
    advancedAuthoring: {
      type:'boolean',
      title: 'Advanced Authoring'
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

export const getLessonData = (data: any) => {
  if (data) {
    const lessonData = data.content.custom;
    return {
      ...lessonData,
      Size: { width: lessonData.defaultScreenWidth, height: lessonData.defaultScreenHeight },
      Appearance: { customCssUrl: lessonData.customCssUrl, headingStyleType: lessonData.headingStyleType,
        renderAccessibleOrderedList: lessonData.renderAccessibleOrderedList,
        showOptionsMenu: !lessonData.hideOptionsMenu,
        globalNumberFormat: lessonData.globalNumberFormat},
      customCSS: data.content.customCss,
      title: data.title
    };
  }
}

export default lessonSchema;
