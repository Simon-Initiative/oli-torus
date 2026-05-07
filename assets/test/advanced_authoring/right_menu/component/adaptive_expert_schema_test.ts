import {
  schema as fibExpertSchema,
  uiSchema as fibExpertUiSchema,
} from 'components/parts/janus-fill-blanks/schema';
import {
  schema as textInputExpertSchema,
  simpleSchema as textInputSimpleSchema,
} from 'components/parts/janus-input-text/schema';
import {
  schema as mcqExpertSchema,
  uiSchema as mcqExpertUiSchema,
  simpleSchema as mcqSimpleSchema,
  simpleUiSchema as mcqSimpleUiSchema,
} from 'components/parts/janus-mcq/schema';
import {
  mergeAdaptiveExpertSchema,
  mergeAdaptiveExpertUiSchema,
} from 'apps/authoring/components/RightMenu/PartPropertyEditor';

describe('advanced author adaptive component schemas', () => {
  it('does not inherit simple-author correctness and feedback fields for MCQ expert mode', () => {
    const merged = mergeAdaptiveExpertSchema(mcqExpertSchema, mcqSimpleSchema);

    expect(merged).not.toHaveProperty('correctAnswer');
    expect(merged).not.toHaveProperty('correctFeedback');
    expect(merged).not.toHaveProperty('incorrectFeedback');
    expect(merged).not.toHaveProperty('commonErrorFeedback');
    expect(merged).not.toHaveProperty('anyCorrectAnswer');
    expect(merged).not.toHaveProperty('mcqItems');

    expect(merged).toHaveProperty('layoutType');
    expect(merged).toHaveProperty('multipleSelection');
    expect(merged).toHaveProperty('randomize');
  });

  it('does not inherit simple-author correctness fields for text input expert mode', () => {
    const merged = mergeAdaptiveExpertSchema(textInputExpertSchema, textInputSimpleSchema);

    expect(merged).not.toHaveProperty('correctAnswer');
    expect(merged).not.toHaveProperty('correctFeedback');
    expect(merged).not.toHaveProperty('incorrectFeedback');

    expect(merged).toHaveProperty('label');
    expect(merged).toHaveProperty('prompt');
    expect(merged).toHaveProperty('enabled');
  });

  it('does not inherit simple-author UI controls for MCQ expert mode', () => {
    const merged = mergeAdaptiveExpertUiSchema(mcqExpertUiSchema, mcqSimpleUiSchema);

    expect(merged).not.toHaveProperty('correctAnswer');
    expect(merged).not.toHaveProperty('correctFeedback');
    expect(merged).not.toHaveProperty('incorrectFeedback');
    expect(merged).not.toHaveProperty('commonErrorFeedback');
    expect(merged).not.toHaveProperty('mcqItems');
    expect(merged).not.toHaveProperty('ui:order');
  });

  it('does not expose simple-author feedback fields for fill in the blanks expert mode', () => {
    const mergedSchema = mergeAdaptiveExpertSchema(fibExpertSchema, null);
    const mergedUiSchema = mergeAdaptiveExpertUiSchema(fibExpertUiSchema, null);

    expect(mergedSchema).not.toHaveProperty('correctFeedback');
    expect(mergedSchema).not.toHaveProperty('incorrectFeedback');
    expect(mergedUiSchema).not.toHaveProperty('correctFeedback');
    expect(mergedUiSchema).not.toHaveProperty('incorrectFeedback');
  });
});
