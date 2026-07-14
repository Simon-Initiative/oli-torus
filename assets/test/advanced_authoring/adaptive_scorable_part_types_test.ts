import { availableQuestionTypes } from '../../src/apps/authoring/components/Flowchart/paths/path-options';
import {
  hasSimpleAuthorQuestionPart,
  questionComponents,
} from '../../src/apps/authoring/components/Flowchart/toolbar/FlowchartHeaderNav';
import {
  adaptiveScorablePartTypes,
  isAdaptiveScorablePartType,
  isManualGradablePartType,
  showsScoringSection,
  transformModelToSchema,
  transformSchemaToModel,
} from '../../src/apps/authoring/components/PropertyEditor/schemas/part';

const normalizeAdaptivePartSlug = (slug: string) => slug.replace(/_/g, '-');

describe('adaptive scorable part types', () => {
  it('covers every authorable adaptive question component', () => {
    for (const type of questionComponents) {
      expect(adaptiveScorablePartTypes.has(normalizeAdaptivePartSlug(type))).toBe(true);
    }
  });

  it('covers every primary adaptive question type used for branching', () => {
    for (const type of availableQuestionTypes) {
      expect(adaptiveScorablePartTypes.has(type)).toBe(true);
    }
  });

  it('includes scored non-primary response types and excludes display-only parts', () => {
    expect(adaptiveScorablePartTypes.has('janus-fill-blanks')).toBe(true);
    expect(adaptiveScorablePartTypes.has('janus-formula')).toBe(false);
  });

  it('treats the capi iframe as manually gradable but not auto-scorable', () => {
    expect(isManualGradablePartType('janus-capi-iframe')).toBe(true);
    expect(isAdaptiveScorablePartType('janus-capi-iframe')).toBe(false);
    expect(showsScoringSection('janus-capi-iframe')).toBe(true);
    // auto-scored inputs are still shown, and non-gradable display parts are not
    expect(showsScoringSection('janus-mcq')).toBe(true);
    expect(showsScoringSection('janus-text-flow')).toBe(false);
  });

  it('does not treat display-only parts as blocking the first simple-author question component', () => {
    expect(
      hasSimpleAuthorQuestionPart({
        content: {
          partsLayout: [
            { type: 'janus-formula' },
            { type: 'janus-popup' },
            { type: 'janus-text-flow' },
          ],
        },
      }),
    ).toBe(false);

    expect(
      hasSimpleAuthorQuestionPart({
        content: {
          partsLayout: [{ type: 'janus-input-text' }],
        },
      }),
    ).toBe(true);
  });

  describe('manual-only part scoring transforms (capi iframe)', () => {
    const buildIframeModel = () => ({
      id: 'iframe-1',
      type: 'janus-capi-iframe',
      custom: {
        x: 0,
        y: 0,
        z: 0,
        width: 400,
        height: 400,
        requiresManualGrading: true,
      },
    });

    it('surfaces only the Requires Manual Grading toggle and injects no feedback defaults', () => {
      const schema = transformModelToSchema(buildIframeModel());

      expect(schema.Scoring).toEqual({ requiresManualGrading: true });
      expect(schema.Scoring.maxScore).toBeUndefined();
      expect(schema.custom.correctFeedback).toBeUndefined();
      expect(schema.custom.incorrectFeedback).toBeUndefined();
    });

    it('round-trips requiresManualGrading without forcing a maxScore or feedback defaults', () => {
      const schema = transformModelToSchema(buildIframeModel());
      const model = transformSchemaToModel(schema);

      expect(model.custom.requiresManualGrading).toBe(true);
      expect(model.custom.maxScore).toBeUndefined();
      expect(model.custom.correctFeedback).toBeUndefined();
      expect(model.custom.incorrectFeedback).toBeUndefined();
    });
  });
});
