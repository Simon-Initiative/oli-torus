import { Size } from 'components/common/resizer/types';
import * as React from 'react';

import { HTMLAttributes, ReactNode, RefObject } from 'react';

import { Consumer, ContextValue } from './context';
import { updateElementDataAttributes } from './utils';

interface ExternalProps extends HTMLAttributes<HTMLDivElement> {
  innerRef?: RefObject<HTMLDivElement>;
  onSizeChanged?: (size: Size) => void;
  updateDataAttributesBySize?: (size: Size) => DOMStringMap;
  children?: ReactNode;
}

interface Props extends ExternalProps {
  innerRef: RefObject<HTMLDivElement>;
  context: ContextValue;
}

function remove(object: any, toRemove: string[]) {
  return Object.entries(object).reduce(
    (acc, [k, v]) => (toRemove.includes(k) ? acc : Object.assign(acc, { [k]: v })),
    {},
  );
}

const ResizeConsumer = (props: Props) => {
  const [size, setSize] = React.useState({ height: 0, width: 0 });

  const divProps = remove(props, [
    'innerRef',
    'onSizeChanged',
    'updateDataAttributesBySize',
    'children',
    'context',
  ]);

  React.useEffect(() => {
    if (size.width !== props.context.size.width || size.height !== props.context.size.height) {
      onSizeChanged();
    }
  }, [size, props]);

  const onSizeChanged = () => {
    const { size } = props.context;

    if (size) {
      if (typeof props.onSizeChanged === 'function') {
        props.onSizeChanged(size);
      }

      updateAttribute(size);
    }
  };

  const updateAttribute = (size: Size) => {
    const element = props.innerRef.current;
    if (element && typeof props.updateDataAttributesBySize === 'function') {
      const newDataAttributes = props.updateDataAttributesBySize(size);
      updateElementDataAttributes(element, newDataAttributes);
    }
  };

  const { innerRef, children } = props;

  return (
    <div {...divProps} ref={innerRef}>
      {children}
    </div>
  );
};

export default ({ innerRef = React.createRef(), ...props }: ExternalProps) => (
  <Consumer>
    {(context) => <ResizeConsumer {...props} context={context} innerRef={innerRef} />}
  </Consumer>
);
