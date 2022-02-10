import { ActivityState, PartComponentDefinition } from 'components/activities/types';
import React from 'react';
import PartComponent from '../common/PartComponent';

interface PartsLayoutRendererProps {
  parts: PartComponentDefinition[];
  state?: ActivityState;
  onPartInit?: any;
  onPartReady?: any;
  onPartSave?: any;
  onPartSubmit?: any;
  onPartResize?: any;
  onPartSetData?: (payload: any) => Promise<any>;
  onPartGetData?: (payload: any) => Promise<any>;
}

const defaultHandler = async () => {
  return {
    type: 'success',
    snapshot: {},
  };
};

const PartsLayoutRenderer: React.FC<PartsLayoutRendererProps> = ({
  parts,
  state = {},
  onPartInit = defaultHandler,
  onPartReady = defaultHandler,
  onPartSave = defaultHandler,
  onPartSubmit = defaultHandler,
  onPartResize = defaultHandler,
  onPartSetData,
  onPartGetData,
}) => {
  return (
    <React.Fragment>
      {parts.map((partDefinition: PartComponentDefinition) => {
        const partProps = {
          id: partDefinition.id,
          type: partDefinition.type,
          model: partDefinition.custom,
          state,
          onInit: onPartInit,
          onReady: onPartReady,
          onSave: onPartSave,
          onSubmit: onPartSubmit,
          onResize: onPartResize,
          onSetData: onPartSetData,
          onGetData: onPartGetData,
        };
        return <PartComponent key={partDefinition.id} {...partProps} />;
      })}
    </React.Fragment>
  );
};

export default PartsLayoutRenderer;
