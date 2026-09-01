import { AccessibilityFindingItem } from 'apps/authoring/store/groups/layouts/deck/actions/accessibilityAudit';

export interface AccessibilityFixConfig {
  label: string;
  fieldPath: string;
  inputType: 'text' | 'textarea';
  allowMarkDecorative?: boolean;
}

const FIX_CONFIGS: Record<string, Partial<Record<string, AccessibilityFixConfig>>> = {
  'janus-popup': {
    missing_description: {
      label: 'Description',
      fieldPath: 'description',
      inputType: 'text',
    },
  },
  'janus-ai-trigger': {
    missing_aria_label: {
      label: 'Accessible Label',
      fieldPath: 'ariaLabel',
      inputType: 'text',
    },
  },
  'janus-image': {
    missing_alt_text: {
      label: 'Alternate text',
      fieldPath: 'alt',
      inputType: 'text',
      allowMarkDecorative: true,
    },
    placeholder_alt_text: {
      label: 'Alternate text',
      fieldPath: 'alt',
      inputType: 'text',
    },
  },
  'janus-formula': {
    missing_alt_text: {
      label: 'Alternate text',
      fieldPath: 'formulaAltText',
      inputType: 'text',
    },
    placeholder_alt_text: {
      label: 'Alternate text',
      fieldPath: 'formulaAltText',
      inputType: 'text',
    },
  },
  'janus-video': {
    missing_aria_label: {
      label: 'ARIA Label',
      fieldPath: 'ariaLabel',
      inputType: 'text',
    },
    missing_audio_description: {
      label: 'Audio Description',
      fieldPath: 'alt',
      inputType: 'text',
    },
  },
  'janus-audio': {
    missing_aria_label: {
      label: 'ARIA Label',
      fieldPath: 'ariaLabel',
      inputType: 'text',
    },
    missing_transcript: {
      label: 'Transcript',
      fieldPath: 'transcript.transcriptText',
      inputType: 'textarea',
    },
  },
};

export const getAccessibilityFixConfig = (
  item: AccessibilityFindingItem,
): AccessibilityFixConfig | null => {
  return FIX_CONFIGS[item.type]?.[item.issue] ?? null;
};

const getValueAtPath = (obj: Record<string, unknown>, fieldPath: string): string => {
  const parts = fieldPath.split('.');
  let current: unknown = obj;
  for (const part of parts) {
    if (current === null || current === undefined || typeof current !== 'object') {
      return '';
    }
    current = (current as Record<string, unknown>)[part];
  }
  return typeof current === 'string' ? current : '';
};

export const getAccessibilitySuggestedFix = (
  item: AccessibilityFindingItem,
  custom: Record<string, unknown> = {},
): string => {
  const config = getAccessibilityFixConfig(item);
  if (!config) {
    return '';
  }
  return getValueAtPath(custom, config.fieldPath);
};
