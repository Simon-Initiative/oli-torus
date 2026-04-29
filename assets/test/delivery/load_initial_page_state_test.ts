import { resolveInitialPreviewSequenceId } from 'apps/delivery/store/features/page/actions/loadInitialPageState';

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
