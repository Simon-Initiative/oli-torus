/* eslint-disable @typescript-eslint/no-var-requires */
import React from 'react';
import { ImageIcon } from './icons/ImageIcon';
import { VideoIcon } from './icons/VideoIcon';
import { TextIcon } from './icons/TextIcon';
import { ComponentListIcon } from './icons/ComponentListIcon';
import { NavButtonIcon } from './icons/NavButtonIcon';
import { MultiChoiceIcon } from './icons/MultiChoiceIcon';
import { UserInputIcon } from './icons/UserInputIcon';
import { PreviewIcon } from './icons/PreviewIcon';
import { PublishIcon } from './icons/PublishIcon';

interface HeaderNavProps {
  content: any;
  isVisible: boolean;
}

const HeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
  const { content, isVisible } = props;
  console.log(content);
  return (
    <nav
      className={`aa-header-nav top-panel${
        isVisible ? ' open' : ''
      } d-flex justify-content-between`}
      style={{ alignItems: 'center' }}
    >
      <div className='col-4'>
        <div className="btn-group" role="group">
          <div className="pr-3 border-right">
            INFINISCOPE{/* Place for Logo */}
          </div>
          <div className="pl-3">
            {content.title}
          </div>
        </div>
      </div>
      <div className="col-7 btn-toolbar" role="toolbar" aria-label="Toolbar with button groups">
        <div className="btn-group pr-3 border-right" role="group" aria-label="First group">
          <div className="px-2">
            <TextIcon />
          </div>
          <div className="px-2">
            <ImageIcon />
          </div>
          <div className="px-2">
            <VideoIcon />
          </div>
        </div>
        <div className="btn-group px-3 border-right" role="group" aria-label="Second group">
          <div className="px-2">
            <NavButtonIcon />
          </div>
          <div className="px-2">
            <MultiChoiceIcon />
          </div>
          <div className="px-2">
            <UserInputIcon />
          </div>
        </div>
        <div className="btn-group pl-3" role="group" aria-label="Third group">
          <div className="px-2">
            <ComponentListIcon />
          </div>
        </div>
      </div>
      <div className='col-1'>
        <div className="btn-group" role="group" aria-label="Third group">
          <div className="px-2">
            <PreviewIcon />
          </div>
          <div className="px-2">
            <PublishIcon />
          </div>
        </div>
      </div>
    </nav>
  );
};

export default HeaderNav;
