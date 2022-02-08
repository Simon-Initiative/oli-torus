export type Handle = 'e' | 's';
export interface Point {
  top: number;
  left: number;
}
export interface BoundingRect extends Point {
  width: number;
  height: number;
}
