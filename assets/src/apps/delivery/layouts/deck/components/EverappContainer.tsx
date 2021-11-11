import { selectActiveEverapp } from 'apps/delivery/store/features/page/slice';
import React from 'react';
import { useSelector } from 'react-redux';
import EverappRenderer, { Everapp } from './EverappRenderer';

export interface EverappContainerProps {
  apps: Everapp[];
}

const EverappContainer: React.FC<EverappContainerProps> = ({ apps }) => {
  const activeAppId = useSelector(selectActiveEverapp);

  const secondaryClass = activeAppId
    ? `beagleOpenApp-${activeAppId}`
    : 'beagleContainer-behindStage';

  return (
    <div className={`beagleContainer ${secondaryClass}`}>
      {apps.map((app: any, idx: number) => (
        <EverappRenderer key={app.id} app={app} index={idx} open={app.id === activeAppId} />
      ))}
    </div>
  );
};

export default EverappContainer;
