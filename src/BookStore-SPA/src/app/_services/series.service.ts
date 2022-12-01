import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';

import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';

import { VideoType } from '../_models/Book';
import { Serie } from '../_models/Category';

@Injectable({
    providedIn: 'root'
})
export class SeriesService {
    private baseUrl: string = environment.baseUrl + 'api/';

    constructor(private http: HttpClient) { }

    public getAll(type:VideoType): Observable<Serie[]> {
        return this.http.get<Serie[]>(this.baseUrl + `series?type=` + <number>type);
    }
    getOther(): Observable<Serie[]> {
        return this.http.get<Serie[]>(this.baseUrl + `series/other`);
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

    public getSerieById(id): Observable<Serie> {
        return this.http.get<Serie>(this.baseUrl + 'series/' + id);
    }

    public search(name: string): Observable<Serie[]> {
        return this.http.get<Serie[]>(`${this.baseUrl}series/search/${name}`);
    }
}
