import {
  resolveInitialPreviewSequenceId,
  seedPreviewVisitHistory,
} from 'apps/delivery/store/features/page/actions/loadInitialPageState';

describe('resolveInitialPreviewSequenceId', () => {
  const sequence = [{ custom: { sequenceId: 'screen_1' } }, { custom: { sequenceId: 'screen_2' } }];

  test('returns the selected preview sequence id when it exists in preview mode', () => {
    expect(resolveInitialPreviewSequenceId(true, 'screen_2', sequence as any)).toBe('screen_2');
  });

  test('returns null when preview mode is disabled', () => {
    expect(resolveInitialPreviewSequenceId(false, 'screen_2', sequence as any)).toBeNull();
  });

  test('returns null when the selected preview sequence id is not in the sequence', () => {
    expect(resolveInitialPreviewSequenceId(true, 'screen_3', sequence as any)).toBeNull();
  });
});

describe('seedPreviewVisitHistory', () => {
  test('seeds prior navigable screens as visited for preview history', () => {
    const sessionState = {
      'session.visits.screen_1': 0,
      'session.visits.screen_2': 0,
      'session.visits.screen_3': 0,
    };
    const sequence = [
      { custom: { sequenceId: 'screen_1' } },
      { custom: { sequenceId: 'bank_1', isBank: true } },
      { custom: { sequenceId: 'screen_2' } },
      { custom: { sequenceId: 'layer_1', isLayer: true } },
      { custom: { sequenceId: 'screen_3' } },
    ];

    const seeded = seedPreviewVisitHistory(sessionState, sequence as any, 'screen_3');

    expect(seeded['session.visits.screen_1']).toBe(1);
    expect(seeded['session.visits.screen_2']).toBe(1);
    expect(seeded['session.visits.screen_3']).toBe(0);
    expect(seeded['session.visitTimestamps.screen_1']).toBeGreaterThan(0);
    expect(seeded['session.visitTimestamps.screen_2']).toBeGreaterThan(
      seeded['session.visitTimestamps.screen_1'],
    );
    expect(seeded['session.visitTimestamps.bank_1']).toBeUndefined();
    expect(seeded['session.visitTimestamps.layer_1']).toBeUndefined();
  });

  test('leaves state unchanged when preview starts on the first screen', () => {
    const sessionState = { 'session.visits.screen_1': 0 };
    const sequence = [{ custom: { sequenceId: 'screen_1' } }];

    const seeded = seedPreviewVisitHistory(sessionState, sequence as any, 'screen_1');

    expect(seeded).toEqual({ 'session.visits.screen_1': 0 });
  });
});
