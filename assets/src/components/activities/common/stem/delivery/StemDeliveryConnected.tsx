import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { HasStem } from 'components/activities/types';
import React from 'react';

interface Props {
  className?: string;
}
export const StemDeliveryConnected: React.FC<Props> = (props) => {
  const { model, writerContext } = useDeliveryElementContext<HasStem>();
  return <StemDelivery stem={model.stem} context={writerContext} {...props} />;
};
