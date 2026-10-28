import React, { createContext, useContext } from 'react';

interface DiagnosticsOverlayContextValue {
  overlayContainer: HTMLElement | null;
}

export const DiagnosticsOverlayContext = createContext<DiagnosticsOverlayContextValue>({
  overlayContainer: null,
});

export const useDiagnosticsOverlay = (): DiagnosticsOverlayContextValue => {
  return useContext(DiagnosticsOverlayContext);
};

interface DiagnosticsOverlayProviderProps {
  overlayContainer: HTMLElement | null;
  children: React.ReactNode;
}

export const DiagnosticsOverlayProvider: React.FC<DiagnosticsOverlayProviderProps> = ({
  overlayContainer,
  children,
}) => {
  return (
    <DiagnosticsOverlayContext.Provider value={{ overlayContainer }}>
      {children}
    </DiagnosticsOverlayContext.Provider>
  );
};
