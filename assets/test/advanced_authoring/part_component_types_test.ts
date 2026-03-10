import { selectPartComponentTypes } from '../../src/apps/authoring/store/app/slice';

const imagePart = { slug: 'janus_image' };
const aiTriggerPart = { slug: 'janus_ai_trigger' };

describe('selectPartComponentTypes', () => {
  it('hides the adaptive AI trigger part when project triggers are disabled', () => {
    const result = selectPartComponentTypes({
      mainApp: {
        partComponentTypes: [imagePart, aiTriggerPart],
        allowTriggers: false,
      },
    } as any);

    expect(result).toEqual([imagePart]);
  });

  it('includes the adaptive AI trigger part when project triggers are enabled', () => {
    const result = selectPartComponentTypes({
      mainApp: {
        partComponentTypes: [imagePart, aiTriggerPart],
        allowTriggers: true,
      },
    } as any);

    expect(result).toEqual([imagePart, aiTriggerPart]);
  });
});
