export class Book {
    id: number;
    seriesId: number;
    name: string;
    displayName: string;
    cover: string;
    seriesName: string;
    currentPosition:number;
    isFinished:boolean;
}

export enum VideoType {
    Unknown,
    Film,
    Animation,
    Episode,
    FairyTale,
    Lessons, 
    Balley
  }