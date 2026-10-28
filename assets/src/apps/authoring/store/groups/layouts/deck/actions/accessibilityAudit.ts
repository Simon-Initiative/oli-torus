import { createAsyncThunk } from '@reduxjs/toolkit';
import { hasTranscriptFromModel } from 'components/parts/janus-audio/transcript';
import { DiagnosticTypes } from 'apps/authoring/components/Modal/diagnostics/DiagnosticTypes';
import { getAccessibilitySuggestedFix } from 'apps/authoring/components/Modal/diagnostics/accessibilityFixConfig';
import { AppSlice } from 'apps/authoring/store/app/name';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryType,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { DiagnosticError, DiagnosticProblem } from './validate';

export interface AccessibilityFindingItem {
  id: string;
  type: string;
  typeLabel: string;
  issue: string;
  message: string;
  parentPopupId?: string;
}

const AUDITABLE_TYPES = new Set([
  'janus-popup',
  'janus-ai-trigger',
  'janus-image',
  'janus-formula',
  'janus-video',
  'janus-audio',
]);

const TYPE_LABELS: Record<string, string> = {
  'janus-popup': 'Popup',
  'janus-ai-trigger': 'AI Activation Point',
  'janus-image': 'Image',
  'janus-formula': 'Formula',
  'janus-video': 'Video',
  'janus-audio': 'Audio',
};

interface AuditablePart {
  id: string;
  type: string;
  custom: Record<string, unknown>;
  parentPopupId?: string;
}

const trimValue = (value: unknown): string => {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
};

const isBlank = (value: unknown): boolean => trimValue(value).length === 0;

const isPlaceholder = (value: unknown, placeholder: string): boolean => {
  const trimmed = trimValue(value);
  if (!trimmed.length) {
    return false;
  }
  return trimmed.toLowerCase() === placeholder.toLowerCase();
};

const normalizeSubtitleTracks = (subtitles: unknown): any[] => {
  if (!subtitles) {
    return [];
  }
  if (Array.isArray(subtitles)) {
    return subtitles;
  }
  if (typeof subtitles === 'object') {
    return [subtitles];
  }
  return [];
};

const hasValidVideoSubtitle = (subtitles: unknown): boolean => {
  return normalizeSubtitleTracks(subtitles).some((track) => {
    const src = trimValue(track?.src);
    const language = trimValue(track?.language || track?.language_code);
    return src.length > 0 && language.length > 0;
  });
};

const makeFinding = (
  part: AuditablePart,
  issue: string,
  message: string,
): AccessibilityFindingItem => ({
  id: part.id,
  type: part.type,
  typeLabel: TYPE_LABELS[part.type] || part.type,
  issue,
  message,
  ...(part.parentPopupId ? { parentPopupId: part.parentPopupId } : {}),
});

const auditPart = (part: AuditablePart): AccessibilityFindingItem[] => {
  const custom = part.custom || {};
  const findings: AccessibilityFindingItem[] = [];

  switch (part.type) {
    case 'janus-popup':
      if (isBlank(custom.description)) {
        findings.push(makeFinding(part, 'missing_description', 'Description is empty or missing.'));
      }
      break;
    case 'janus-ai-trigger':
      if (isBlank(custom.ariaLabel)) {
        findings.push(
          makeFinding(part, 'missing_aria_label', 'Accessible Label is empty or missing.'),
        );
      }
      break;
    case 'janus-image':
      if (!custom.decorative) {
        if (isBlank(custom.alt)) {
          findings.push(
            makeFinding(part, 'missing_alt_text', 'Alternate text is empty or missing.'),
          );
        } else if (isPlaceholder(custom.alt, 'an image')) {
          findings.push(
            makeFinding(
              part,
              'placeholder_alt_text',
              'Alternate text uses the generic placeholder "an image".',
            ),
          );
        }
      }
      break;
    case 'janus-formula':
      if (isBlank(custom.formulaAltText)) {
        findings.push(makeFinding(part, 'missing_alt_text', 'Alternate text is empty or missing.'));
      } else if (isPlaceholder(custom.formulaAltText, 'Sample formula')) {
        findings.push(
          makeFinding(
            part,
            'placeholder_alt_text',
            'Alternate text uses the generic placeholder "Sample formula".',
          ),
        );
      }
      break;
    case 'janus-video':
      if (!hasValidVideoSubtitle(custom.subtitles)) {
        findings.push(
          makeFinding(
            part,
            'missing_subtitles',
            'No valid subtitle track is configured (requires a source and language).',
          ),
        );
      }
      if (isBlank(custom.ariaLabel)) {
        findings.push(makeFinding(part, 'missing_aria_label', 'ARIA Label is empty or missing.'));
      }
      if (isBlank(custom.alt)) {
        findings.push(
          makeFinding(part, 'missing_audio_description', 'Audio Description is empty or missing.'),
        );
      }
      break;
    case 'janus-audio':
      if (isBlank(custom.ariaLabel)) {
        findings.push(makeFinding(part, 'missing_aria_label', 'ARIA Label is empty or missing.'));
      }
      if (!hasTranscriptFromModel(custom)) {
        findings.push(
          makeFinding(
            part,
            'missing_transcript',
            'Neither transcript text nor a transcript file is provided.',
          ),
        );
      }
      break;
    default:
      break;
  }

  return findings;
};

const collectAuditableParts = (partsLayout: any[], parentPopupId?: string): AuditablePart[] => {
  const parts: AuditablePart[] = [];

  (partsLayout || []).forEach((part: any) => {
    if (!part?.id || !part?.type) {
      return;
    }

    if (AUDITABLE_TYPES.has(part.type)) {
      parts.push({
        id: part.id,
        type: part.type,
        custom: part.custom || {},
        ...(parentPopupId ? { parentPopupId } : {}),
      });
    }

    if (part.type === 'janus-popup' && part.custom?.popup?.partsLayout) {
      parts.push(...collectAuditableParts(part.custom.popup.partsLayout, part.id));
    }
  });

  return parts;
};

export const diagnoseAccessibility = (
  allActivities: any[],
  sequence: SequenceEntry<SequenceEntryType>[],
): DiagnosticError[] => {
  const errors: DiagnosticError[] = [];

  allActivities.forEach((activity) => {
    const owner = sequence.find((s) => s.resourceId === activity.id);
    if (!owner) {
      return;
    }

    const auditableParts = collectAuditableParts(activity.content?.partsLayout || []);
    const problems: DiagnosticProblem[] = auditableParts.flatMap((part) =>
      auditPart(part).map((finding) => ({
        owner,
        type: DiagnosticTypes.ACCESSIBILITY,
        suggestedFix: getAccessibilitySuggestedFix(finding, part.custom),
        item: finding,
      })),
    );

    if (problems.length > 0) {
      errors.push({
        activity: owner,
        problems,
      });
    }
  });

  return errors;
};

export const countAccessibilityFindings = (errors: DiagnosticError[]): number => {
  return errors.reduce((count, error) => count + error.problems.length, 0);
};

export const validateAccessibility = createAsyncThunk<any, any, any>(
  `${AppSlice}/validateAccessibility`,
  async (_payload, { getState, fulfillWithValue }) => {
    const rootState = getState();
    const allActivities = selectAllActivities(rootState as any);
    const sequence = selectSequence(rootState as any);
    const errors = diagnoseAccessibility(allActivities, sequence);

    return fulfillWithValue({ errors });
  },
);
