import { VideoType } from './Book';
import { Seasons } from './Seasons';

export class Serie {
    id: number;
    name: string;
    type: VideoType;
    isOrderMatter: boolean;

    seasons: Seasons[]
}

export class AddToPlaylistDTO {
    fileId: number;
    playlistId: number;
}