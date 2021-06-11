/* eslint-disable react/jsx-key */
/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable react/prop-types */

import React from 'react';
const Accordion: React.FC<any> = (props) => {

  const tabs: [] = props.tabsData.tabs;
  console.log(props.data);
  return (
    <div className='accordion' id='accordionExample'>
      {tabs.map((tab: any, index:number) => (
        <div className='card'>
          <div id={tab.id}
            className='d-flex justify-content-between'>
              <span className='col-10'
                data-toggle='collapse'
                data-target={'#collapse'+tab.id}
                aria-expanded='true'
                aria-controls={'collapse'+tab.id}>
                  {tab.title}
              </span>
              <button type='button' className='btn btn-info some-button col-2'>
                <span > + </span>
            </button>
          </div>

          <div
            id={'collapse' + tab.id}
            className={'collapse show'}
            aria-labelledby={tab.id}
          >
            <div className='card-body'>
              <ul className="list-group list-group-flush">
                {tab.data.map((item: any) => (
                  <li className="list-group-item">{item}</li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};

export default Accordion;
