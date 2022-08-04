import React from 'react';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { Formula } from '../../../common/Formula';

import { FormulaModal } from './FormulaModal';
import { modalActions } from '../../../../actions/modal';

interface Props extends EditorProps<ContentModel.FormulaBlock | ContentModel.FormulaInline> {}
export const FormulaEditor = (props: Props) => {
  const onEdit = useEditModelCallback(props.model);

  if (props.model.src === undefined)
    return (
      <div {...props.attributes} contentEditable={false}>
        FORMULA PLACEHOLDER
      </div>
    );

  interface EditableProps {
    subtype: ContentModel.FormulaSubTypes;
    src: string;
  }

  const onFormulaClick = () => {
    window.oliDispatch(
      modalActions.display(
        <FormulaModal
          model={props.model}
          onDone={({ src, subtype }: Partial<EditableProps>) => {
            window.oliDispatch(modalActions.dismiss());
            onEdit({ src, subtype });
          }}
          onCancel={() => window.oliDispatch(modalActions.dismiss())}
        />,
      ),
    );
  };

  return (
    <span {...props.attributes} contentEditable={false}>
      {props.children}

      <Formula
        onClick={onFormulaClick}
        style={{ cursor: 'pointer' }}
        type={props.model.type}
        subtype={props.model.subtype}
        src={props.model.src}
      />
    </span>
  );
};
