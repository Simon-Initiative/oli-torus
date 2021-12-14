import React from 'react';
import { TextEditor } from '../TextEditor';
import { classNames } from 'utils/classNames';
// Title bar component that allows title bar editing and displays
// any collection of child components
export const TitleBar = (props) => {
    const { editMode, className, title, onTitleEdit, children } = props;
    return (<div className={classNames([
            'TitleBar',
            'd-flex flex-column flex-md-row align-items-baseline my-2',
            className,
        ])}>
      <div className="d-flex align-items-baseline flex-grow-1 mr-2">
        <TextEditor onEdit={onTitleEdit} model={title} showAffordances={true} size="large" allowEmptyContents={false} editMode={editMode}/>
      </div>
      {children}
    </div>);
};
//# sourceMappingURL=TitleBar.jsx.map