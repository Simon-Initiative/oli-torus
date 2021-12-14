import * as React from 'react';
export const DragHandle = (props) => {
    const { hidden = false, style = {} } = props;
    return (<div className={`drag-handle ${hidden ? 'invisible' : ''}`} style={style}>
      <div className="grip"/>
    </div>);
};
//# sourceMappingURL=DragHandle.jsx.map