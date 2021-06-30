import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { ChoiceId, HasChoices } from 'components/activities/types';
import { ActivityDeliveryState, isEvaluated } from 'data/content/activities/DeliveryState';
import React from 'react';
import { useSelector } from 'react-redux';

interface Props {
  onSelect: (id: ChoiceId) => void;
  unselectedIcon: React.ReactNode;
  selectedIcon: React.ReactNode;
}
export const ChoicesDeliveryConnected: React.FC<Props> = ({
  onSelect,
  unselectedIcon,
  selectedIcon,
}) => {
  const { model, writerContext } = useDeliveryElementContext<HasChoices>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  return (
    <ChoicesDelivery
      unselectedIcon={unselectedIcon}
      selectedIcon={selectedIcon}
      choices={model.choices}
      selected={uiState.selectedChoices}
      onSelect={onSelect}
      isEvaluated={isEvaluated(uiState)}
      context={writerContext}
    />
  );
};
