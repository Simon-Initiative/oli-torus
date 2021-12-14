import React from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
export const StemAuthoring = ({ stem, onEdit }) => {
    return (<div className="flex-grow-1">
      <RichTextEditorConnected value={stem.content} onEdit={onEdit} placeholder="Question"/>
    </div>);
};
//# sourceMappingURL=StemAuthoring.jsx.map