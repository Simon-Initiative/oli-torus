import { selectPartComponentTypes } from '../../src/apps/authoring/store/app/slice';
import { aiTriggerPartSlug } from '../../src/components/parts/janus-ai-trigger/constants';

const imagePart = { slug: 'janus_image' };
const aiTriggerPart = { slug: aiTriggerPartSlug };

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
