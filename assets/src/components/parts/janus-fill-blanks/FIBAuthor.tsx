import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import Select2 from 'react-select2-wrapper';
import { FIBModel } from './schema';

const FIBAuthor: React.FC<AuthorPartComponentProps<FIBModel>> = (props) => {
  const { model } = props;

  const {
    x = 0,
    y = 0,
    z = 0,
    width,
    height,
    content,
    elements,
    alternateCorrectDelimiter,
    customCss,
  } = model;
  const styles: CSSProperties = {
    borderRadius: '5px',
    fontFamily: 'revert',
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  const contentList = content?.map(
    (contentItem: { [x: string]: any; insert: any; dropdown: any }) => {
      if (!elements?.length) return;

      const insertList: any[] = [];
      let insertEl: any;

      if (contentItem.insert) {
        // contentItem.insert is always a string
        insertList.push(<span dangerouslySetInnerHTML={{ __html: contentItem.insert }} />);
      } else if (contentItem.dropdown) {
        // get correlating dropdown from `elements`
        insertEl = elements.find((elItem: { key: any }) => elItem.key === contentItem.dropdown);
        if (insertEl) {
          // build list of options for react-select
          const optionsList = insertEl.options.map(
            ({ value: text, key: id }: { value: any; key: any }) => ({ id, text }),
          );

          insertList.push(
            <span className="dropdown-blot" tabIndex={-1}>
              <span className="dropdown-container" tabIndex={-1}>
                <Select2
                  className={`dropdown incorrect`}
                  name={insertEl.key}
                  data={optionsList}
                  aria-label="Make a selection"
                  options={{
                    minimumResultsForSearch: 10,
                    selectOnClose: false,
                  }}
                  disabled={true}
                />
              </span>
            </span>,
          );
        }
      } else if (contentItem['text-input']) {
        // get correlating inputText from `elements`
        insertEl = elements.find((elItem: { key: any }) => {
          return elItem.key === contentItem['text-input'];
        });
        if (insertEl) {
          const answerStatus = 'incorrect';

          insertList.push(
            <span className="text-input-blot">
              <span className={`text-input-container ${answerStatus}`} tabIndex={-1}>
                <input
                  name={insertEl.key}
                  className={`text-input disabled`}
                  type="text"
                  disabled={true}
                />
              </span>
            </span>,
          );
        }
      }
      return insertList;
    },
  );
  return (
    <div data-janus-type={tagName} style={styles} className={`fib-container`}>
      <style type="text/css">{`${customCss}`};</style>
      <div className="scene">
        <div className="app">
          <div className="editor ql-container ql-snow ql-disabled">
            <div
              className="ql-editor"
              data-gramm="false"
              contentEditable="false"
              suppressContentEditableWarning={true}
            >
              <p>{contentList}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export const tagName = 'janus-fill-blanks';

export default FIBAuthor;
