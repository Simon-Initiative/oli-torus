import React, { useMemo } from 'react';
import { defaultWriterContext } from 'data/content/writers/context';
import { ChoiceId, HasChoices, HasStem } from 'components/activities/types';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { useAuthoringElementContext } from 'components/activities/AuthoringElement';

interface Props {
  selectedChoiceIds: ChoiceId[];
  onSelectChoiceId: (id: ChoiceId) => void;
  selectedIcon: React.ReactNode;
  unselectedIcon: React.ReactNode;
}
export const AnswerKey: React.FC<Props> = ({
  selectedChoiceIds,
  onSelectChoiceId,
  selectedIcon,
  unselectedIcon,
}) => {
  const context = useMemo(defaultWriterContext, []);
  const { model } = useAuthoringElementContext<HasChoices & HasStem>();
  return (
    <>
      <StemDelivery stem={model.stem} context={context} />

      <ChoicesDelivery
        unselectedIcon={unselectedIcon}
        selectedIcon={selectedIcon}
        choices={model.choices}
        selected={selectedChoiceIds}
        onSelect={onSelectChoiceId}
        isEvaluated={false}
        context={context}
      />
    </>
  );
};
