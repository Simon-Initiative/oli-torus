import React, { useMemo } from 'react';
import { defaultWriterContext } from 'data/content/writers/context';
import { Choice, ChoiceId, Stem } from 'components/activities/types';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';

interface Props {
  stem: Stem;
  choices: Choice[];
  selectedChoiceIds: ChoiceId[];
  onSelectChoiceId: (id: ChoiceId) => void;
  selectedIcon: React.ReactNode;
  unselectedIcon: React.ReactNode;
}
export const AnswerKeyAuthoring: React.FC<Props> = ({
  stem,
  choices,
  selectedChoiceIds,
  onSelectChoiceId,
  selectedIcon,
  unselectedIcon,
}) => {
  const context = useMemo(defaultWriterContext, []);
  return (
    <>
      <div className="d-flex">
        <StemDelivery stem={stem} context={context} />
      </div>

      <ChoicesDelivery
        unselectedIcon={unselectedIcon}
        selectedIcon={selectedIcon}
        choices={choices}
        selected={selectedChoiceIds}
        onSelect={onSelectChoiceId}
        isEvaluated={false}
        context={context}
      />
    </>
  );
};
