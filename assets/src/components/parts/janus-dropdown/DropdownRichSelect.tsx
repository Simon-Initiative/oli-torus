import React, { useEffect, useRef, useState } from 'react';
import { sanitizeRichLabelHtml } from '../../../utils/richOptionLabel';

export interface DropdownRichSelectProps {
  id: string;
  prompt?: string;
  optionLabels: string[];
  /** 1-based index, or <= 0 when showing prompt / none */
  selectedIndex: number;
  disabled: boolean;
  onChange: (oneBasedIndex: number) => void;
  style?: React.CSSProperties;
  className?: string;
}

const menuStyle: React.CSSProperties = {
  position: 'absolute',
  top: '100%',
  left: 0,
  right: 0,
  width: '100%',
  minWidth: '100%',
  boxSizing: 'border-box',
  zIndex: 3000,
  maxHeight: 280,
  overflowY: 'auto',
  overflowX: 'hidden',
  margin: 0,
  padding: 0,
  borderRadius: '0 0 4px 4px',
  border: '1px solid rgba(0,0,0,.15)',
  backgroundColor: '#fff',
  listStyle: 'none',
};

/**
 * Accessible custom dropdown that can render sanitized HTML in options (native select cannot).
 */
export const DropdownRichSelect: React.FC<DropdownRichSelectProps> = ({
  id,
  prompt,
  optionLabels,
  selectedIndex,
  disabled,
  onChange,
  style,
  className,
}) => {
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) {
      return;
    }
    const close = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, [open]);

  const sanitized = optionLabels.map((l) => sanitizeRichLabelHtml(l || ''));
  const sanitizedPrompt = sanitizeRichLabelHtml(prompt || '');

  const showPromptInButton = selectedIndex <= 0;
  const triggerHtml = showPromptInButton
    ? sanitizedPrompt
    : sanitized[selectedIndex - 1] ?? '';

  return (
    <div
      ref={wrapRef}
      className={`janus-dropdown-rich position-relative${className ? ` ${className}` : ''}`}
      style={{ width: '100%', ...style, zIndex: open ? 2000 : undefined }}
    >
      <style>{`
        .janus-dropdown-rich-menu li {
          padding: 6px 16px;
          cursor: pointer;
          white-space: normal;
          word-break: break-word;
          color: #212529;
        }
        .janus-dropdown-rich-menu li:hover {
          background-color: #f8f9fa;
        }
        .janus-dropdown-rich-menu li.is-selected {
          background-color: #343a40;
          color: #fff;
        }
        .janus-dropdown-rich-menu li.is-prompt {
          color: #6c757d;
        }
        .janus-dropdown-rich-menu .janus-rich-dropdown-option-inner p {
          display: inline;
          margin: 0;
        }
      `}</style>

      <button
        type="button"
        id={`${id}-select`}
        className="form-select text-start d-flex align-items-center"
        style={{ minHeight: 42, width: '100%' }}
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={`${id}-listbox`}
        onClick={() => !disabled && setOpen((o) => !o)}
        onKeyDown={(e) => {
          if (e.key === 'Escape') {
            setOpen(false);
          }
          if ((e.key === 'ArrowDown' || e.key === 'Enter' || e.key === ' ') && !open) {
            e.preventDefault();
            setOpen(true);
          }
        }}
      >
        <span
          className="flex-grow-1 janus-rich-dropdown-option-inner text-truncate"
          dangerouslySetInnerHTML={{ __html: triggerHtml || '\u00a0' }}
        />
      </button>

      {open ? (
        <ul id={`${id}-listbox`} role="listbox" className="janus-dropdown-rich-menu" style={menuStyle}>
          {/* Prompt as first item — mirrors native disabled first <option> */}
          {sanitizedPrompt ? (
            <li
              role="option"
              aria-selected={false}
              aria-disabled
              className="is-prompt"
              onMouseDown={(e) => e.preventDefault()}
              onClick={() => setOpen(false)}
            >
              <span
                className="janus-rich-dropdown-option-inner"
                dangerouslySetInnerHTML={{ __html: sanitizedPrompt }}
              />
            </li>
          ) : null}

          {sanitized.map((labelHtml, index) => {
            const oneBased = index + 1;
            const isSelected = selectedIndex === oneBased;
            return (
              <li
                key={oneBased}
                role="option"
                aria-selected={isSelected}
                className={isSelected ? 'is-selected' : ''}
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => {
                  setOpen(false);
                  onChange(oneBased);
                }}
              >
                <span
                  className="janus-rich-dropdown-option-inner"
                  dangerouslySetInnerHTML={{ __html: labelHtml }}
                />
              </li>
            );
          })}
        </ul>
      ) : null}
    </div>
  );
};
