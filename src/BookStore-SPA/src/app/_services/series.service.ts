import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';

import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';

import {
  AudioType,
  VideoType,
} from '../_models/Book';
import { Serie } from '../_models/Category';

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
    private baseUrl: string = environment.baseUrl + 'api/';

    constructor(private http: HttpClient) { }

    public getAll(type:VideoType): Observable<Serie[]> {
        return this.http.get<Serie[]>(this.baseUrl + `series?type=` + <number>type);
    }
    public getAllAudio(type:AudioType): Observable<Serie[]> {
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
    getSpecial(): Observable<Serie[]> {
        return this.http.get<Serie[]>(this.baseUrl + `series/special`);
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
