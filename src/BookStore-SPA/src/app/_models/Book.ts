import { SafeHtml } from '@angular/platform-browser';

export class Book {
    id: number;
    seriesId: number;
    seasonId: number;
    name: string;
    displayName: string;
    cover: string;
    seriesName: string;
    seasoName: string;
    currentPosition:number;
    durationMinutes:number;
    isFinished:boolean;
    isSupportedWebPlayer:boolean;
    previousFilesDurationSeconds:number;

    description: string;
    year: number;
    genres: string;
    director: string;

    isSelected:boolean;

    PlayURL: SafeHtml;
    coverURL: SafeHtml;
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
    Courses,
    Downloaded,
    Youtube,
    EoT,
    Special
}

export enum VideoOrigin {
    Unknown,
    Soviet,
    Russian,
    Foreign
}


export class AudioFile extends Book {
    index : number;
}

export enum AudioType {
    Unknown,
    Music,
    Podcast,
    EoT,
    FairyTale,
    Lessons
}
