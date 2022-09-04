export class Book {
    id: number;
    seriesId: number;
    name: string;
    displayName: string;
    cover: string;
    seriesName: string;
    currentPosition:number;
    durationMinutes:number;
    isFinished:boolean;
    
    description: string;
    year: string;
    genres: string;
    director: string;
}

export enum VideoType {
    Unknown,
    Film,
    Animation,
    ChildEpisode,
    FairyTale,
    Lessons, 
    Balley,
    AdultEpisode,
    Courses
  }