/* eslint-disable react/jsx-key */
/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable react/prop-types */

import React from 'react';
const TabStrip: React.FC<any> = (props) => {

  const tabs: [] = props.tabsData.tabs;
  //console.log(props.data);
  return (
<div>
    <ul className='nav nav-tabs' role='tablist'>
      {tabs.map((tab: any, index:number) => (
        <li className='nav-item'>
          <a id={`${tab.id}-tab`}
            data-toggle='tab'
            role='tab'
            aria-controls={`tab${tab.id}` }
            aria-selected={index == 0}
           className={'nav-link ' + (index == 0? 'active':'')}
           href={`#tab${tab.id}`}>{tab.title}</a>
        </li>
      ))}
  </ul>

  <div className='tab-content' id='myTabContent'>
    {tabs.map((tab: any, index: number) => (
      <div className={`tab-pane fade${index == 0 ? ' show active':''}`}
        id={`tab${tab.id}` }
        role='tabpanel'
        aria-labelledby={`${tab.id}-tab`}>
          {tab.data}
      </div>
    ))}
    </div>
</div>
  );
};

export default TabStrip;
