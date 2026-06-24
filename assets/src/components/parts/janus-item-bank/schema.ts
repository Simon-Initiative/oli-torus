import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export const DEFAULT_GROUPING_MIN_HEIGHT = 425;
export const RESPONSIVE_GROUPING_MIN_HEIGHT = 400;

export type GroupingItemType = 'text' | 'image';

export interface GroupingItem {
  // unique, stable id used internally for drag/drop and correct-answer mapping
  id: string;
  type: GroupingItemType;
  // short label, acts as the unique human identifier used in CAPI keys
  label: string;
  // text content (used when type === 'text'); falls back to label when empty
  text?: string;
  // image source (used when type === 'image')
  imageSrc?: string;
  // alternative text for the image (accessibility)
  alt?: string;
}

export interface GroupingCategory {
  id: string;
  title: string;
}

export interface GroupingModel extends JanusAbsolutePositioned, JanusCustomCss {
  enabled: boolean;
  // hex color theme applied to the component (e.g. #0070F3)
  themeColor: string;
  // author-provided custom CSS or @import statements
  customCss?: string;
  items: GroupingItem[];
  categories: GroupingCategory[];
  // maps item id -> category id for manage-mode layout (authoring preview)
  layoutPlacements: Record<string, string>;
  // maps item id -> category id for the correct placement
  correctAnswer: Record<string, string>;
  showHints?: boolean;
  showCorrect?: boolean;
}

const bankDataProperties: JSONSchema7Object = {
  manageItems: {
    title: 'Manage Item Bank',
    type: 'array',
    items: { type: 'string' },
    description:
      'Create items and categories, then switch to Set Answer to define the correct grouping.',
  },
};

const bankDataUiSchema = {
  manageItems: { 'ui:widget': 'ItemBankManageEditor' },
};

export const schema: JSONSchema7Object = {
  ...bankDataProperties,
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'specifies whether the learner can interact with the component',
    default: true,
  },
  themeColor: {
    title: 'Theme Color',
    type: 'string',
    description: 'Hex color used for the component accent (e.g. #0070F3)',
    default: '#0070F3',
  },
  customCss: {
    title: 'Custom CSS',
    type: 'string',
    description: 'Custom CSS or an @import url(...) for an external stylesheet',
    default: '',
  },
  showHints: {
    title: 'Show Hints',
    type: 'boolean',
    description: 'When enabled, marks correct/incorrect items with a check or X',
    default: false,
  },
};

export const simpleSchema: JSONSchema7Object = {
  ...bankDataProperties,
  themeColor: {
    title: 'Theme Color',
    type: 'string',
    description: 'Hex color used for the component accent (e.g. #0070F3)',
    default: '#0070F3',
  },
  customCss: {
    title: 'Custom CSS',
    type: 'string',
    description: 'Custom CSS or an @import url(...) for an external stylesheet',
    default: '',
  },
  showHints: {
    title: 'Show Hints',
    type: 'boolean',
    description: 'When enabled, marks correct/incorrect items with a check or X',
    default: false,
  },
};

export const uiSchema = {
  'ui:order': ['manageItems', '*'],
  ...bankDataUiSchema,
  themeColor: {
    'ui:widget': 'ColorPicker',
  },
  customCss: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 4,
    },
  },
};

export const simpleUiSchema = {
  'ui:order': ['manageItems', 'themeColor', 'showHints', 'customCss'],
  ...bankDataUiSchema,
  themeColor: {
    'ui:widget': 'ColorPicker',
  },
  customCss: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 4,
    },
  },
};

/**
 * Adaptivity schema is dynamic: in addition to the always-present control and
 * status variables, it exposes one location variable per item (keyed by the
 * item's short label) and one count variable per category (keyed by title).
 */
export const adaptivitySchema = ({ currentModel }: { currentModel: any }) => {
  const adaptivity: Record<string, CapiVariableTypes> = {};
  adaptivity.enabled = CapiVariableTypes.BOOLEAN;
  adaptivity.userModified = CapiVariableTypes.BOOLEAN;
  adaptivity.correct = CapiVariableTypes.BOOLEAN;
  adaptivity.showCorrect = CapiVariableTypes.BOOLEAN;
  adaptivity.showHints = CapiVariableTypes.BOOLEAN;
  adaptivity.itemBankCount = CapiVariableTypes.NUMBER;

  const categories: GroupingCategory[] = currentModel?.custom?.categories || [];
  const items: GroupingItem[] = currentModel?.custom?.items || [];

  categories.forEach((category, index) => {
    const title = (category?.title || `Category ${index + 1}`).trim();
    adaptivity[`${title}.Count`] = CapiVariableTypes.NUMBER;
  });

  items.forEach((item, index) => {
    const label = (item?.label || `Item ${index + 1}`).trim();
    adaptivity[`${label}.Location`] = CapiVariableTypes.STRING;
  });

  return adaptivity;
};

export const getCapabilities = () => ({
  configure: false,
});

export const createSchema = (): Partial<GroupingModel> => {
  const categories: GroupingCategory[] = [
    { id: 'category-1', title: 'Category 1' },
    { id: 'category-2', title: 'Category 2' },
  ];

  const items: GroupingItem[] = [
    {
      id: 'item-1',
      type: 'text',
      label: 'Draggable Item One',
      text: 'Draggable Item One',
    },
    {
      id: 'item-2',
      type: 'text',
      label: 'Draggable Item Two',
      text: 'Draggable Item Two',
    },
  ];

  return {
    enabled: true,
    customCssClass: '',
    themeColor: '#0070F3',
    customCss: '',
    height: DEFAULT_GROUPING_MIN_HEIGHT,
    showHints: false,
    showCorrect: false,
    categories,
    items,
    layoutPlacements: {},
    correctAnswer: {},
  };
};
