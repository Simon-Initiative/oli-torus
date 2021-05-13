import PartComponent from './PartComponent';
import React, { CSSProperties } from 'react';
import chroma from 'chroma-js';

// NOTE: this should not be rendering the parts directly eventually
// it should render any activity? not just adaptive?
// the adaptive-activity web component should render
// the parts
const ActivityRenderer: React.FC<any> = (props: any) => {
  const { activity } = props;

  const config = activity.content.custom;

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
      {activity.content.partsLayout.map((partDefinition: any) => {
        const partProps = {
          id: partDefinition.id,
          type: partDefinition.type,
          model: partDefinition.custom,
          state: [],
          onInit: async () => true,
          onReady: async () => true,
          onSave: async () => true,
          onSubmit: async () => true,
        };
        return <PartComponent key={partDefinition.id} {...partProps} />;
      })}
    </div>
  );
};

export default ActivityRenderer;
