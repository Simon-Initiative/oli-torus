import { SequenceBank, SequenceEntry, SequenceEntryType } from './sequence';

// returns the next random QB child
export const getNextQBEntry = (
  sequence: SequenceEntry<SequenceEntryType>[],
  bank: SequenceEntry<SequenceBank>,
  viewHistory: { sequenceId: string; visitCount: number }[],
): SequenceEntry<SequenceEntryType> | null => {
  // determines how many QB child screens to randomly show
  const bankShowCount: number = bank.custom?.bankShowCount || 0;
  const bankChildren = getBankChildren(sequence, bank);
  const viewedChildren = getViewedChildren(bankChildren, viewHistory);
  if (viewedChildren.length >= bankShowCount) {
    return getQBEndTarget(sequence, bank);
  }
  const remainingChildren = getRemainingChildren(bankChildren, viewedChildren);
  // generates a random index based on remainingChildren.length
  const random: number = Math.floor(Math.random() * remainingChildren.length);

  // return the next random QB child screen
  return remainingChildren[random];
};

// finds the parent QB of the current screen
export const getParentBank = (
  sequence: SequenceEntry<SequenceEntryType>[],
  currentIndex: number,
): SequenceEntry<SequenceBank> | null => {
  const bank = sequence.find(
    (s) =>
      s.custom.sequenceId === sequence[currentIndex].custom.layerRef && s.custom.isBank === true,
  );
  return (bank as SequenceEntry<SequenceBank>) || null;
};

// generates a list of all the QB child screens
export const getBankChildren = (
  sequence: SequenceEntry<SequenceEntryType>[],
  parentBank: SequenceEntry<SequenceBank>,
): SequenceEntry<SequenceEntryType>[] =>
  sequence.filter((s) => s.custom.layerRef === parentBank.custom.sequenceId);

// generates a list of QB child screens that have already been viewed
export const getViewedChildren = (
  bankChildren: SequenceEntry<SequenceEntryType>[],
  viewHistory: { sequenceId: string; visitCount: number }[],
): string[] => {
  return viewHistory.filter((v) => v.visitCount >= 1).map((v) => v.sequenceId);
};

// determines which QB children are remaining to be viewed
export const getRemainingChildren = (
  bankChildren: SequenceEntry<SequenceEntryType>[],
  viewedChildrenIds: string[],
): SequenceEntry<SequenceEntryType>[] =>
  bankChildren.filter((bc) => !viewedChildrenIds.includes(bc.custom.sequenceId));

// returns the bankEndTarget of the QB
export const getQBEndTarget = (
  sequence: SequenceEntry<SequenceEntryType>[],
  parentBank: SequenceEntry<SequenceBank>,
): SequenceEntry<SequenceEntryType> | null => {
  const bankEndTarget = parentBank.custom.bankEndTarget;
  const bankChildren = getBankChildren(sequence, parentBank);
  //** if bankEndTarget = next or undefined then we need to find the correct next ensemble to navigate to */
  //** if bankEndTarget is something like q:1573069617189:646 then do nothing */
  if ((bankChildren && bankEndTarget === 'next') || !bankEndTarget) {
    const lastQBChild = bankChildren[bankChildren.length - 1].custom.sequenceId;
    const currentIndex = sequence.findIndex((s) => s.custom.sequenceId === lastQBChild);
    const nextIndex = currentIndex + 1;
    return sequence[nextIndex];
  }

  return sequence.find((s) => s.custom.sequenceId === bankEndTarget) || null;
};
