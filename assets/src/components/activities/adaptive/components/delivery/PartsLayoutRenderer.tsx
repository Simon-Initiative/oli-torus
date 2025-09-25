import React from 'react';
import { ActivityState, PartComponentDefinition } from 'components/activities/types';
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
  responsiveLayout?: boolean;
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
  responsiveLayout = true,
}) => {
  return (
    <>
      {responsiveLayout ? (
        <div className="advance-authoring-responsive-layout">
          {parts.map((partDefinition: PartComponentDefinition) => {
            const partProps = {
              id: partDefinition.id,
              type: partDefinition.type,
              model: {
                ...partDefinition.custom,
                // In responsive mode, ignore x,y positions but preserve original data
                x: 0, // Ignore x position in responsive mode (but preserve original x in data)
                y: 0, // Ignore y position in responsive mode (but preserve original y in data)
              },
              state,
              onInit: onPartInit,
              onReady: onPartReady,
              onSave: onPartSave,
              onSubmit: onPartSubmit,
              onResize: onPartResize,
              onSetData: onPartSetData,
              onGetData: onPartGetData,
            };
            // Determine width class and alignment
            const widthClass =
              partDefinition.custom.width === '100%' ||
              typeof partDefinition.custom.width !== 'string' ||
              partDefinition.custom.width === undefined ||
              partDefinition.custom.width === null
                ? 'full-width'
                : 'half-width';
            const alignmentClass =
              partDefinition.custom.width === '50% align right'
                ? 'responsive-align-right'
                : 'responsive-align-left';

            return (
              <div
                key={partDefinition.id}
                data-part-id={partDefinition.id}
                className={`responsive-item ${widthClass} ${alignmentClass}`}
              >
                <PartComponent key={partDefinition.id} {...partProps} />{' '}
              </div>
            );
          })}
        </div>
      ) : (
        parts.map((partDefinition: PartComponentDefinition) => {
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
        })
      )}
    </>
  );
};

export default PartsLayoutRenderer;
