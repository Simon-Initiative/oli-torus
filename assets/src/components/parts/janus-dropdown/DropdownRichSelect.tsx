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
  minWidth: 0,
  maxWidth: '100%',
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

const triggerStyle: React.CSSProperties = {
  width: '100%',
  minHeight: 38,
  height: 38,
  boxSizing: 'border-box',
  display: 'flex',
  alignItems: 'center',
  textAlign: 'left',
  padding: '0.375rem 2.25rem 0.375rem 0.75rem',
  lineHeight: 1.5,
  border: '1px solid #000',
  borderRadius: 4,
  backgroundColor: '#fff',
  color: '#212529',
  backgroundImage:
    "url(\"data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3e%3cpath fill='none' stroke='%23343a40' stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='m2 5 6 6 6-6'/%3e%3c/svg%3e\")",
  backgroundRepeat: 'no-repeat',
  backgroundPosition: 'right 0.75rem center',
  backgroundSize: '16px 12px',
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
  const triggerHtml = showPromptInButton ? sanitizedPrompt : sanitized[selectedIndex - 1] ?? '';

  return (
    <div
      ref={wrapRef}
      className={`janus-dropdown-rich position-relative${className ? ` ${className}` : ''}`}
      style={{ width: '100%', ...style, zIndex: open ? 2000 : undefined }}
    >
      <style>{`
        .janus-dropdown-rich-trigger:focus,
        .janus-dropdown-rich-trigger:focus-visible {
          border-color: rgb(0, 101, 134);
          outline: 0;
          box-shadow: 0 0 0 0.25rem rgba(0, 101, 134, 0.25);
        }
        .janus-dropdown-rich-trigger:disabled {
          background-color: #e9ecef;
          opacity: 1;
          cursor: not-allowed;
        }
        .janus-dropdown-rich-menu li {
          padding: 6px 16px;
          cursor: pointer;
          white-space: normal;
          word-break: break-word;
          color: #212529;
        }
        .janus-dropdown-rich-menu li:hover {
          background-color: gray;
          color: #fff;
        }
        .janus-dropdown-rich-menu li.is-selected {
          background-color: #6c757d;
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
        className="janus-dropdown-rich-trigger"
        style={triggerStyle}
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
        <ul
          id={`${id}-listbox`}
          role="listbox"
          className="janus-dropdown-rich-menu"
          style={menuStyle}
        >
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
