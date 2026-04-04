import { availableQuestionTypes } from '../../src/apps/authoring/components/Flowchart/paths/path-options';
import { questionComponents } from '../../src/apps/authoring/components/Flowchart/toolbar/FlowchartHeaderNav';
import { adaptiveScorablePartTypes } from '../../src/apps/authoring/components/PropertyEditor/schemas/part';

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
});
