import React, { useRef } from 'react';
import { PreviewTab } from './types';

interface Props {
  tabs: PreviewTab[];
  activeTabId: string;
  onTabChange: (tabId: string) => void;
}

const nextIndex = (currentIndex: number, length: number) => (currentIndex + 1) % length;
const prevIndex = (currentIndex: number, length: number) => (currentIndex - 1 + length) % length;

export const PreviewTabs: React.FC<Props> = ({ tabs, activeTabId, onTabChange }) => {
  const tabRefs = useRef<(HTMLButtonElement | null)[]>([]);

  const focusTab = (index: number) => {
    tabRefs.current[index]?.focus();
    onTabChange(tabs[index].id);
  };

  return (
    <div className="flex flex-col gap-4">
      <div
        className="flex flex-wrap border-b border-Border-border-default"
        role="tablist"
        aria-label="Preview details"
      >
        {tabs.map((tab, index) => {
          const isActive = tab.id === activeTabId;

          return (
            <button
              key={tab.id}
              ref={(el) => (tabRefs.current[index] = el)}
              id={`preview-tab-${tab.id}`}
              role="tab"
              type="button"
              tabIndex={isActive ? 0 : -1}
              aria-selected={isActive}
              aria-controls={`preview-panel-${tab.id}`}
              className={`-mb-px border-0 border-b-2 bg-transparent px-3 py-4 text-sm leading-4 text-Text-text-high ${
                isActive
                  ? 'border-Fill-Buttons-fill-primary font-semibold'
                  : 'border-transparent font-normal hover:text-Text-text-medium'
              }`}
              onClick={() => onTabChange(tab.id)}
              onKeyDown={(event) => {
                switch (event.key) {
                  case 'ArrowRight':
                  case 'ArrowDown':
                    event.preventDefault();
                    focusTab(nextIndex(index, tabs.length));
                    break;
                  case 'ArrowLeft':
                  case 'ArrowUp':
                    event.preventDefault();
                    focusTab(prevIndex(index, tabs.length));
                    break;
                  case 'Home':
                    event.preventDefault();
                    focusTab(0);
                    break;
                  case 'End':
                    event.preventDefault();
                    focusTab(tabs.length - 1);
                    break;
                }
              }}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      {tabs.map((tab) => {
        const isActive = tab.id === activeTabId;

        return (
          <div
            key={tab.id}
            id={`preview-panel-${tab.id}`}
            role="tabpanel"
            aria-labelledby={`preview-tab-${tab.id}`}
            hidden={!isActive}
          >
            {isActive ? tab.content : null}
          </div>
        );
      })}
    </div>
  );
};
