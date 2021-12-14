import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';
import './StemDelivery.scss';
export const StemDelivery = (props) => {
    return (<div className={`stem__delivery${props.className ? ' ' + props.className : ''}`}>
      <HtmlContentModelRenderer content={props.stem.content} context={props.context}/>
    </div>);
};
export const StemDeliveryConnected = (props) => {
    const { model, writerContext } = useDeliveryElementContext();
    return <StemDelivery stem={model.stem} context={writerContext} {...props}/>;
};
//# sourceMappingURL=StemDelivery.jsx.map