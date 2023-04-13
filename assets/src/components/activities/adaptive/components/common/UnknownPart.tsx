import React, { CSSProperties, useEffect } from 'react';
import register from 'components/parts/customElementWrapper';
import { customEvents } from 'components/parts/partsApi';
import { PartComponentProps } from 'components/parts/types/parts';

const Unknown: React.FC<PartComponentProps<any>> = (props) => {
  console.log('UNKNOWN RENDER', { props });
  const { model } = props;

  const { x, y, z, width } = model;
  const styles: CSSProperties = {
    /* position: 'absolute',
    top: y,
    left: x, */
    width,
    // height,
    zIndex: z,
    backgroundColor: 'magenta',
    overflow: 'hidden',
    fontWeight: 'bold',
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div data-part_component-type={props.type} style={styles}>
      <p>Unknown Part Component Type:</p>
      <p>{props.type}</p>
    </div>
  );
};

export const tagName = 'unknown-component';

// only register once since this might be shared with another part component (popup)
if (!customElements.get(tagName)) {
  register(Unknown, tagName, ['id', 'type', 'model'], {
    shadow: true,
    customEvents: { ...customEvents },
    attrs: {
      model: {
        json: true,
      },
    },
  });
}

export default Unknown;
