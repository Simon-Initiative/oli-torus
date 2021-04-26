export interface Size {
  width: number;
  height: number;
}

export type OnResizeCallBack = (size: Size) => void;