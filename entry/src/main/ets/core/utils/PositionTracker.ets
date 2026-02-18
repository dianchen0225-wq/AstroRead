export class PositionTracker {
  private _index: number = 0;

  constructor(startIndex: number = 0) {
    this._index = startIndex;
  }

  get index(): number {
    return this._index;
  }

  set index(value: number) {
    this._index = value;
  }

  advance(count: number = 1): void {
    this._index += count;
  }

  retreat(count: number = 1): void {
    this._index = Math.max(0, this._index - count);
  }

  reset(startIndex: number = 0): void {
    this._index = startIndex;
  }

  clone(): PositionTracker {
    return new PositionTracker(this._index);
  }

  isAt(position: number): boolean {
    return this._index === position;
  }

  isBefore(position: number): boolean {
    return this._index < position;
  }

  isAfter(position: number): boolean {
    return this._index > position;
  }

  distanceTo(position: number): number {
    return Math.abs(this._index - position);
  }

  toString(): string {
    return `PositionTracker(index=${this._index})`;
  }
}

export default PositionTracker;
