/* eslint-disable @typescript-eslint/no-var-requires */
import React, { useState } from 'react';
const text = require("./icons/icon-text.svg") as string;
const image = require("./icons/icon-image.svg") as string;
const video = require("./icons/icon-video.svg") as string;
const navButton = require("./icons/icon-navButton.svg") as string;
const multiChoice = require("./icons/icon-multiChoice.svg") as string;
const userInput = require("./icons/icon-userInput.svg") as string;
const componentList = require("./icons/icon-componentList.svg") as string;
const preview = require("./icons/icon-preview.svg") as string;
const publish = require("./icons/icon-publish.svg") as string;

interface HeaderNavProps {
  content: any;
  isVisible: boolean;
}

const HeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
  const { content, isVisible } = props;
  return (
    <nav className={`aa-header-nav top-panel${isVisible ? ' open' : ''} d-flex justify-content-between`}
        style={{alignItems: 'center'}}>
      <div>{content.title}</div>
      <div className="btn-toolbar" role="toolbar" aria-label="Toolbar with button groups">
        <div className="btn-group me-2" role="group" aria-label="First group">
          <img className='px-2' src={text} />
          <img className='px-2' src={image} />
          <img className='px-2' src={video} />
        </div>
        <div className="btn-group me-2" role="group" aria-label="Second group">
          <img className='px-2' src={navButton} />
          <img className='px-2' src={multiChoice} />
          <img className='px-2' src={userInput} />
        </div>
        <div className="btn-group" role="group" aria-label="Third group">
          <img className='px-2' src={componentList} />
        </div>
      </div>
      <div>
        <div className="btn-group" role="group" aria-label="Third group">
          <img className='px-2' src={preview} />
          <img className='px-2' src={publish} />
        </div>
      </div>
    </nav>
  );
};

export default HeaderNav;
