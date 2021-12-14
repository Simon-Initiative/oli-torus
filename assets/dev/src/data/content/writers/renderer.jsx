import React from 'react';
import { HtmlParser } from './html';
import { ContentWriter } from './writer';
export const HtmlContentModelRenderer = (props) => {
    // Support content persisted when RichText had a `model` property.
    const content = props.content.model ? props.content.model : props.content;
    return (<div style={props.style}>
      {new ContentWriter().render(props.context, content, new HtmlParser())}
    </div>);
};
//# sourceMappingURL=renderer.jsx.map