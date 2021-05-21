/* eslint-disable react/prop-types */
import React, { useEffect, useState } from 'react';
import Unknown from './UnknownComponent';

const WebComponent: React.FC<any> = (props) => {
  // TODO: build from configuration instead
  const wcEvents: any = {
    init: props.onInit,
    ready: props.onReady,
    save: props.onSave,
    submit: props.onSubmit,
  };

  const [listening, setIsListening] = useState(false);
  useEffect(() => {
    const wcEventHandler = async (e: any) => {
      const { payload, callback } = e.detail;
      if (payload.id !== props.id) {
        // because we need to listen to document we'll get all part component events
        // each PC adds a listener, so we need to filter out our own here
        return;
      }
      const handler = wcEvents[e.type];
      if (handler) {
        const result = await handler(payload);
        if (callback) {
          callback(result);
        }
      }
    };
    Object.keys(wcEvents).forEach((eventName) => {
      document.addEventListener(eventName, wcEventHandler);
    });
    setIsListening(true);
    return () => {
      Object.keys(wcEvents).forEach((eventName) => {
        document.removeEventListener(eventName, wcEventHandler);
      });
    };
  }, []);

  const webComponentProps = {
    id: props.id,
    type: props.type,
    ...props,
    model: JSON.stringify(props.model),
    state: JSON.stringify(props.state),
  };

  const wcTagName = props.type;
  if (!wcTagName || !customElements.get(wcTagName)) {
    const unknownProps = { ...webComponentProps, ref: undefined };
    return <Unknown {...unknownProps} />;
  }

  // don't render until we're listening because otherwise the init event will post too fast
  return listening ? React.createElement(wcTagName, webComponentProps) : null;
};

export default WebComponent;
