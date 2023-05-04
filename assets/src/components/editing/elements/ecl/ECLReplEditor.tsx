import React, { PropsWithChildren, Suspense, useEffect, useRef, useState } from 'react';
import { WrappedMonaco } from 'components/activities/common/variables/WrappedMonaco';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';

type ECLEditorProps = EditorProps<ContentModel.ECLRepl>;
export const ECLReplEditor = (props: PropsWithChildren<ECLEditorProps>) => {
  const [model] = useState(props.model);
  const onEdit = useEditModelCallback(model);

  return (
    <div style={{ backgroundColor: '#EEEEEE', padding: '10px', borderRadius: '6px' }}>
      <div style={{ color: 'darkgray' }}>
        <strong>ECL</strong>
      </div>
      <WrappedMonaco
        language="mathematica"
        model={model.code}
        editMode={true}
        onEdit={(code) => onEdit({ code })}
      />
      <small>Enter the ECL code, if any, that you want the student to start with.</small>
    </div>
  );
};
