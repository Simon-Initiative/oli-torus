import { CommandButtonToggleState } from '../../data/content/model/elements/types';

const isToggleState = (value: unknown): value is CommandButtonToggleState => {
  if (!value || typeof value !== 'object') return false;
  const candidate = value as Partial<CommandButtonToggleState>;
  return typeof candidate.title === 'string' && typeof candidate.message === 'string';
};

const toToggleStates = (value: unknown): CommandButtonToggleState[] | null => {
  if (!Array.isArray(value)) return null;
  const toggleStates = value.filter(isToggleState);
  return toggleStates.length === value.length && toggleStates.length > 0 ? toggleStates : null;
};

export const parseToggleStatesFromDataAttribute = (
  json: string | null | undefined,
): CommandButtonToggleState[] | null => {
  if (!json) return null;

  try {
    const parsed = JSON.parse(json);
    return toToggleStates(parsed);
  } catch {
    return null;
  }
};

export const selectCurrentAndNextToggleState = (
  toggleStates: CommandButtonToggleState[],
  currentTitle?: string,
) => {
  // Toggle state semantics:
  // - Match the currently displayed title as current state
  // - Send the current state's message
  // - Advance the displayed title to the next state (wrapping around)
  // - If no title matches, fall back to the first state
  const normalizedTitle = (currentTitle || '').trim();
  const currentIndex = toggleStates.findIndex((d) => d.title.trim() === normalizedTitle);
  const resolvedCurrentIndex = currentIndex === -1 ? 0 : currentIndex;
  const nextIndex = (resolvedCurrentIndex + 1) % toggleStates.length;
  return {
    currentState: toggleStates[resolvedCurrentIndex],
    nextState: toggleStates[nextIndex],
  };
};
