/* eslint-disable react/prop-types */
import { PartComponentDefinition } from 'components/activities/types';
import React from 'react';
import PartComponent from './PartComponent';

interface PartsLayoutRendererProps {
  parts: PartComponentDefinition[];
  state?: any[];
  onPartInit?: any;
  onPartReady?: any;
  onPartSave?: any;
  onPartSubmit?: any;
}

const defaultHandler = async () => {
  return true;
};

const PartsLayoutRenderer: React.FC<PartsLayoutRendererProps> = ({
  parts,
  state = [],
  onPartInit = defaultHandler,
  onPartReady = defaultHandler,
  onPartSave = defaultHandler,
  onPartSubmit = defaultHandler,
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
        };
        return <PartComponent key={partDefinition.id} {...partProps} />;
      })}
    </React.Fragment>
  );
};

export default PartsLayoutRenderer;
