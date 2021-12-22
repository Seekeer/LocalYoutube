import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Serie } from '../_models/Category';
import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';

@Injectable({
    providedIn: 'root'
})
export class SeriesService {
    private baseUrl: string = environment.baseUrl + 'api/';

    constructor(private http: HttpClient) { }

    public getAll(): Observable<Serie[]> {
        return this.http.get<Serie[]>(this.baseUrl + `series`);
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

    public getCategoryById(id): Observable<Serie> {
        return this.http.get<Serie>(this.baseUrl + 'series/' + id);
    }

    public search(name: string): Observable<Serie[]> {
        return this.http.get<Serie[]>(`${this.baseUrl}series/search/${name}`);
    }
}
