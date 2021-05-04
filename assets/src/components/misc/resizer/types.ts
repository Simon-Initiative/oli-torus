export type Position = 'nw' | 'n' | 'ne' | 'w' | 'e' | 'sw' | 's' | 'se';
export interface Point {
  top: number;
  left: number;
}
export interface BoundingRect extends Point {
  width: number;
  height: number;
}
