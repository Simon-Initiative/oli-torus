/* eslint-disable react/prop-types */
import chroma from 'chroma-js';
import { PartComponentDefinition } from 'components/activities/types';
import React, { CSSProperties } from 'react';
import PartComponent from './PartComponent';

interface PartsLayoutRendererProps {
  parts: PartComponentDefinition[];
  config: any;
  state?: any[];
  onPartInit?: any;
  onPartReady?: any;
  onPartSave?: any;
  onPartSubmit?: any;
}

const defaultHandler = async () => true;

const PartsLayoutRenderer: React.FC<PartsLayoutRendererProps> = ({
  parts,
  config,
  state = [],
  onPartInit = defaultHandler,
  onPartReady = defaultHandler,
  onPartSave = defaultHandler,
  onPartSubmit = defaultHandler,
}) => {
  const styles: CSSProperties = {
    width: config.width || 1300,
  };
  if (config?.palette) {
    if (config.palette.useHtmlProps) {
      styles.backgroundColor = config.palette.backgroundColor;
      styles.borderColor = config.palette.borderColor;
      styles.borderWidth = config.palette.borderWidth;
      styles.borderStyle = config.palette.borderStyle;
      styles.borderRadius = config.palette.borderRadius;
    } else {
      styles.borderWidth = `${
        config?.palette?.lineThickness ? config?.palette?.lineThickness + 'px' : '1px'
      }`;
      styles.borderRadius = '10px';
      styles.borderStyle = 'solid';
      styles.borderColor = `rgba(${
        config?.palette?.lineColor || config?.palette?.lineColor === 0
          ? chroma(config?.palette?.lineColor).rgb().join(',')
          : '255, 255, 255'
      },${config?.palette?.lineAlpha})`;
      styles.backgroundColor = `rgba(${
        config?.palette?.fillColor || config?.palette?.fillColor === 0
          ? chroma(config?.palette?.fillColor).rgb().join(',')
          : '255, 255, 255'
      },${config?.palette?.fillAlpha})`;
    }
  }
  if (config?.x) {
    styles.left = config.x;
  }
  if (config?.y) {
    styles.top = config.y;
  }
  if (config?.z) {
    styles.zIndex = config.z || 0;
  }
  if (config?.height) {
    styles.height = config.height;
  }

  return (
    <div className="content" style={styles}>
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
    </div>
  );
};

export default PartsLayoutRenderer;
