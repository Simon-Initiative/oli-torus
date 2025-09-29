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
  // Helper function to create part props
  const createPartProps = (partDefinition: PartComponentDefinition) => {
    return {
      id: partDefinition.id,
      type: partDefinition.type,
      model: responsiveLayout
        ? {
            ...partDefinition.custom,
            // In responsive mode, ignore x,y positions but preserve original data
            x: 0, // Ignore x position in responsive mode (but preserve original x in data)
            y: 0, // Ignore y position in responsive mode (but preserve original y in data)
            // In responsive mode, set width to 100% for the part
            width: '100%',
          }
        : partDefinition.custom, // Use original model in non-responsive mode
      state,
      onInit: onPartInit,
      onReady: onPartReady,
      onSave: onPartSave,
      onSubmit: onPartSubmit,
      onResize: onPartResize,
      onSetData: onPartSetData,
      onGetData: onPartGetData,
    };
  };

  // Helper function to render individual parts
  const renderPart = (partDefinition: PartComponentDefinition) => {
    const partProps = createPartProps(partDefinition);

    if (responsiveLayout) {
      // Determine width class and alignment for responsive layout
      const widthClass =
        partDefinition.custom.width === 960 ||
        partDefinition.custom.width === '100%' ||
        typeof partDefinition.custom.width !== 'number' ||
        partDefinition.custom.width === undefined ||
        partDefinition.custom.width === null
          ? 'full-width'
          : 'half-width';
      const alignmentClass =
        partDefinition.custom.width === 471 ? 'responsive-align-right' : 'responsive-align-left';

      return (
        <div
          key={partDefinition.id}
          data-part-id={partDefinition.id}
          style={{ height: partDefinition?.custom?.height }}
          className={`responsive-item ${widthClass} ${alignmentClass}`}
        >
          <PartComponent key={partDefinition.id} {...partProps} />
        </div>
      );
    } else {
      // Non-responsive mode - direct rendering
      return <PartComponent key={partDefinition.id} {...partProps} />;
    }
  };

  return (
    <>
      {responsiveLayout ? (
        <div className="advance-authoring-responsive-layout">{parts.map(renderPart)}</div>
      ) : (
        parts.map(renderPart)
      )}
    </>
  );
};

export default PartsLayoutRenderer;
