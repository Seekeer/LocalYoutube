import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';

import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';

import {
  AudioType,
  VideoOrigin,
  VideoType,
} from '../_models/Book';
import { AddToPlaylistDTO, Serie } from '../_models/Category';

@Injectable({
    providedIn: 'root'
})
export class SeriesService {
    moveSeasonToFavorite(seasonId: number) {
        return this.http.get<Serie[]>(this.baseUrl + `series/moveSeasonToFavorite?seasonId=${seasonId}&favorite=true`);
    }
    moveSeasonToBlackList(seasonId: number) {
        return this.http.get<Serie[]>(this.baseUrl + `series/moveSeasonToFavorite?seasonId=${seasonId}&favorite=false`);
    }
    moveSeasonToSeries(fileId:number, serieId: number) {
        return this.http.get<Serie[]>(this.baseUrl + `series/moveSeasonToSeries?fileId=${fileId}&seriesId=${serieId}`);
    }
    private baseUrl: string = environment.baseUrl + 'api/';

    constructor(private http: HttpClient) { }

    public getPlaylists(): Observable<Serie[]> {
        return this.http.get<Serie[]>(this.baseUrl + `playlists/getAll`);
    }
    
    addToPlaylist(playlistId: number, videoId: number) {
        let dto = new AddToPlaylistDTO();
        dto.fileId = videoId;
        dto.playlistId = playlistId;
        return this.http.post(this.baseUrl + 'playlists/addToPlaylist', dto);
    }

    public getAll(type:VideoType|null, origin:VideoOrigin|null = null): Observable<Serie[]> {
        if(type == null)
            return this.http.get<Serie[]>(this.baseUrl + `series/getAllByOrigin?origin=${<number>origin}`);
        else
            return this.http.get<Serie[]>(this.baseUrl + `series/getAllByType?type=${<number>type}`);
    }

    public getAllAudioSeries(type:AudioType): Observable<Serie[]> {
        if(!type)
            return this.http.get<Serie[]>(this.baseUrl + `series/getAllAudio?exceptType=${AudioType.FairyTale}`);
        else
            return this.http.get<Serie[]>(this.baseUrl + `series/getAllAudio?type=` + <number>type);
        // return this.http.get<Serie[]>(this.baseUrl + `series/getAllAudio`);
    }
    getCourses(): Observable<Serie[]> {
        return this.http.get<Serie[]>(this.baseUrl + `series/courses`);
    }
    getAdultEpisode(): Observable<Serie[]> {
        return this.http.get<Serie[]>(this.baseUrl + `series/adultEpisode`);
    }
    getSpecialAndEot(): Observable<Serie[]> {
        return this.http.get<Serie[]>(this.baseUrl + `series/specialAndEot`);
    }
    
    public getCategories(): Observable<Serie[]> {
        return this.http.get<Serie[]>(this.baseUrl + `series`);
    }

    public addCategory(category: Serie) {
        return this.http.post(this.baseUrl + 'Series', category);
    }

    public updateCategory(id: number, category: Serie) {
        return this.http.put(this.baseUrl + 'series/' + id, category);
    }

    public deleteCategory(id: number) {
        return this.http.delete(this.baseUrl + 'series/' + id);
    }

    public deleteSeason(id: number) {
        return this.http.delete(this.baseUrl + 'series/season/' + id);
    }

    public getSerieById(id): Observable<Serie> {
        return this.http.get<Serie>(this.baseUrl + 'series/' + id);
    }

    public search(name: string): Observable<Serie[]> {
        return this.http.get<Serie[]>(`${this.baseUrl}series/search/${name}`);
    }
}
