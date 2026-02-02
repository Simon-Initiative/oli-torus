import React from 'react';
import { useSelector } from 'react-redux';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { ActivityModelSchema, ChoiceId, HasChoices, PartId } from 'components/activities/types';
import { ActivityDeliveryState, isEvaluated } from 'data/activities/DeliveryState';

interface Props {
  partId: PartId;
  onSelect: (id: ChoiceId) => void;
  unselectedIcon: React.ReactNode;
  selectedIcon: React.ReactNode;
  multiSelect?: boolean;
}
export const ChoicesDeliveryConnected: React.FC<Props> = ({
  onSelect,
  unselectedIcon,
  selectedIcon,
  partId,
  multiSelect = false,
}) => {
  const { writerContext } = useDeliveryElementContext<HasChoices & ActivityModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  return (
    <ChoicesDelivery
      unselectedIcon={unselectedIcon}
      selectedIcon={selectedIcon}
      choices={(uiState.model as HasChoices).choices}
      selected={uiState.partState[partId]?.studentInput || []}
      onSelect={onSelect}
      isEvaluated={isEvaluated(uiState)}
      context={writerContext}
      multiSelect={multiSelect}
    />
  );
};
