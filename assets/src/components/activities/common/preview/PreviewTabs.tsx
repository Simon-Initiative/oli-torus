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
        className="flex flex-wrap gap-2 border-b border-gray-200 pb-2"
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
              className={`rounded-t px-1 py-2 text-sm font-semibold ${
                isActive
                  ? 'border-0 border-b-2 border-primary bg-transparent text-primary'
                  : 'border-0 bg-transparent text-gray-500'
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
