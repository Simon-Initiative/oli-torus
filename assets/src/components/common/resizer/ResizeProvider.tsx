import { Size } from 'components/common/resizer/types';
import * as React from 'react';
import { findDOMNode } from 'react-dom';

import { ContextValue, Provider } from './context';
import { getResizeDetector, getSize } from './utils';

interface Props {
  size: Size;
}

const ResizeProvider: React.FunctionComponent<Props> = (props) => {
  const [size, setSize] = React.useState<Size>({ width: 0, height: 0 });

  const currentListenElement: HTMLElement | null = null;

  React.useEffect(() => {
    updateListenElement();

    return () => removeListener(currentListenElement);
  })

  const measureID?: any;

  const mutateID?: any;

  const updateListenElement = () => {
    listenTo(getElement());
  }

  const onSizeChanged = (element: HTMLElement) => {
    fastdom.clear(measureID);

    measureID = fastdom.measure(() => {
      const size = getSize(element);
      updateSize(size);
    });
  };

  const updateSize = (size: Size) => {
    fastdom.clear(mutateID);

    mutateID = fastdom.mutate(() => {
      setState({ size: size });
    });
  };

  const getElement = () => {
    const element = findDOMNode(this);
    return element instanceof HTMLElement ? element : null;
  }

  const listenTo = (element: HTMLElement | null) => {
    removeListener(currentListenElement);

    currentListenElement = element;

    if (element) {
      getResizeDetector().listenTo(element, onSizeChanged);
    }
  }

  const removeListener = (element: HTMLElement | null) => {
    if (element) {
      getResizeDetector().removeListener(element, onSizeChanged);
    }
  }

  return <Provider value={size}>{props.children}</Provider>;
}

export default ResizeProvider;
