import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { HasStem } from 'components/activities/types';
import React from 'react';

export const StemDeliveryConnected: React.FC = () => {
  const { model, writerContext } = useDeliveryElementContext<HasStem>();
  return <StemDelivery stem={model.stem} context={writerContext} />;
};
