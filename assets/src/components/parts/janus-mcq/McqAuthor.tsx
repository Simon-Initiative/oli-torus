import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { MCQItem } from './MultipleChoiceQuestion';
import { McqModel } from './schema';

const McqAuthor: React.FC<AuthorPartComponentProps<McqModel>> = (props) => {
  const { id, model } = props;

  const {
    x = 0,
    y = 0,
    z = 0,
    width,
    multipleSelection,
    mcqItems,
    customCssClass,
    layoutType,
    height,
    overrideHeight = false,
  } = model;
  const styles: CSSProperties = {
    width,
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  const options: any[] = mcqItems?.map((item: any, index: number) => ({
    ...item,
    index: index,
    value: index + 1,
  }));

  let columns = 1;
  if (customCssClass === 'two-columns') {
    columns = 2;
  }
  if (customCssClass === 'three-columns') {
    columns = 3;
  }
  if (customCssClass === 'four-columns') {
    columns = 4;
  }

  return (
    <div data-janus-type={tagName} style={styles} className={`mcq-input`}>
      <style>
        {`
          .mcq-input>div {
            margin: 1px 6px 10px 0 !important;
            display: block;
            position: static !important;
            min-height: 20px;
            line-height: normal !important;
            vertical-align: middle;
          }
          .mcq-input>div>label {
            margin: 0 !important;
          }
          .mcq-input>br {
            display: none !important;
          }
        `}
      </style>
      {options?.map((item, index) => (
        <MCQItem
          index={index}
          key={`${id}-item-${index}`}
          totalItems={options.length}
          layoutType={layoutType}
          itemId={`${id}-item-${index}`}
          groupId={`mcq-${id}`}
          val={item.value}
          {...item}
          x={0}
          y={0}
          overrideHeight={overrideHeight}
          disabled={false}
          multipleSelection={multipleSelection}
          columns={columns}
        />
      ))}
    </div>
  );
};

export const tagName = 'janus-mcq';

export default McqAuthor;
