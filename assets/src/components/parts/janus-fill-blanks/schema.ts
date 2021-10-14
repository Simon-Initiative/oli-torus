import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface FIBModel extends JanusAbsolutePositioned, JanusCustomCss {
  cssClasses: string;
  fontSize?: number;
  showHints: boolean;
  enabled: boolean;
  alternateCorrectDelimiter: string;
  showCorrect: boolean;
  showSolution: boolean;
  formValidation: boolean;
  caseSensitiveAnswers: boolean;
  content: any;
  elements: any;
}

export const schema: JSONSchema7Object = {
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

export const adaptivitySchema = ({ currentModel }: { currentModel: any }) => {
  const adaptivitySchema: Record<string, unknown> = {};
  const elementData: Record<string, unknown>[] = currentModel?.custom?.elements;

  adaptivitySchema.attempted = CapiVariableTypes.BOOLEAN;
  adaptivitySchema.correct = CapiVariableTypes.BOOLEAN;
  adaptivitySchema.customCss = CapiVariableTypes.STRING;
  adaptivitySchema.customCssClass = CapiVariableTypes.STRING;
  adaptivitySchema.enabled = CapiVariableTypes.BOOLEAN;

  if (elementData.length > 0) {
    elementData.forEach((element: Record<string, unknown>, index: number) => {
      adaptivitySchema[`Input ${index + 1}.Value`] = CapiVariableTypes.STRING;
      adaptivitySchema[`Input ${index + 1}.Correct`] = CapiVariableTypes.BOOLEAN;
      adaptivitySchema[`Input ${index + 1}.Alternate Correct`] = CapiVariableTypes.STRING;
    });
  }
  return adaptivitySchema;
};

export const createSchema = (): Partial<FIBModel> => ({
  cssClasses: '',
  customCss: '',
  showHints: false,
  showCorrect: false,
  alternateCorrectDelimiter: '',
  caseSensitiveAnswers: false,
});
