import { SafeHtml } from '@angular/platform-browser';

export class Book {
    id: number;
    seriesId: number;
    seasonId: number;
    name: string;
    displayName: string;
    cover: string;
    seriesName: string;
    currentPosition:number;
    durationMinutes:number;
    isFinished:boolean;
    isSupportedWebPlayer:boolean;
    
    description: string;
    year: string;
    genres: string;
    director: string;

    isSelected:boolean;

    PlayURL: SafeHtml;
    hours:string;
}

export enum VideoType {
    Unknown,
    Film,
    Animation,
    ChildEpisode,
    FairyTale,
    Lessons, 
    Art,
    AdultEpisode,
    Courses
  }