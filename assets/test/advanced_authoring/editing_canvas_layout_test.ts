import { buildPartLayoutUpdatePayload } from '../../src/apps/authoring/components/EditingCanvas/partLayout';

describe('EditingCanvas part layout persistence', () => {
  test('includes flashcard height and cardHeight in the update payload', () => {
    expect(
      buildPartLayoutUpdatePayload('activity-1', 'flashcards-1', {
        height: 572,
        cardHeight: 180,
        ignored: 42,
      }),
    ).toEqual({
      activityId: 'activity-1',
      partId: 'flashcards-1',
      changes: {
        custom: {
          height: 572,
          cardHeight: 180,
        },
      },
      mergeChanges: true,
    });
  });
});
