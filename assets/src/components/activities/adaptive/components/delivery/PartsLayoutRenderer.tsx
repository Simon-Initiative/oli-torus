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
    // Special handling for janus-image parts with lockAspectRatio in responsive mode
    const isJanusImageWithLockAspectRatio =
      responsiveLayout &&
      partDefinition.type === 'janus-image' &&
      partDefinition.custom.lockAspectRatio === true;

    return {
      id: partDefinition.id,
      type: partDefinition.type,
      model: responsiveLayout
        ? {
            ...partDefinition.custom,
            // In responsive mode, ignore x,y positions but preserve original data
            x: 0, // Ignore x position in responsive mode (but preserve original x in data)
            y: 0, // Ignore y position in responsive mode (but preserve original y in data)
            // In responsive mode, set width to 100% for the part, except for janus-image with lockAspectRatio
            width: !isJanusImageWithLockAspectRatio ? '100%' : partDefinition.custom.width,
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
      // Determine width class and alignment for responsive layout using responsiveLayoutWidth
      const responsiveWidth = partDefinition.custom.responsiveLayoutWidth || 960; // Default to 100% if not set
      const widthClass =
        responsiveWidth === 960 ||
        responsiveWidth === '100%' ||
        typeof responsiveWidth !== 'number' ||
        responsiveWidth === undefined ||
        responsiveWidth === null
          ? 'full-width'
          : 'half-width';
      const alignmentClass =
        responsiveWidth === 471 ? 'responsive-align-right' : 'responsive-align-left';

      return (
        <div
          key={partDefinition.id}
          data-part-id={partDefinition.id}
          style={{ height: 'auto', minHeight: 'fit-content' }}
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
