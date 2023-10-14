import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';

import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';

import {
  Book,
  VideoType,
} from '../_models/Book';
import { Mark } from '../_models/Mark';

@Injectable({
    providedIn: 'root'
})
export class FileService {
    private baseUrl: string = environment.baseUrl + 'api/';

    constructor(private http: HttpClient) { }

    public getMarksByFile(fileId:number) {
        return this.http.get<Mark[]>(`${this.baseUrl}marks/getAllMarks?fileId=${fileId}`);
    }
    public deleteMark(fileId: number) {
        return this.http.delete(this.baseUrl + 'marks/' + fileId);
    }
    public addMarkByFile(mark: Mark): Observable<number> {
        return this.http.post<number>(this.baseUrl + 'marks/add', mark);
    }

    public getFilmsByType(type: VideoType) {
        return this.http.get<Book[]>(`${this.baseUrl}files/getFileByType/${type}`);
    }

    public getLatest() {
        return this.http.get<Book[]>(`${this.baseUrl}files/getLatest`);
    }

    public filmStarted(fileId: number) {
        return this.http.patch(`${this.baseUrl}files/filmStarted`, fileId);
    }
    
    public getFilmsByTypeUniqueSeason(type: VideoType) {
        return this.http.get<Book[]>(`${this.baseUrl}files/getFileByTypeUniqueSeason/${type}`);
    }
    public getSovietAnimation() {
        return this.http.get<Book[]>(`${this.baseUrl}files/getAnimation?isSoviet=true`);
    }
    getBigAnimation() {
        return this.http.get<Book[]>(`${this.baseUrl}files/getAnimation?isSoviet=false`);
    }

    public getVideoURLById(id: number) {
        return this.baseUrl +'Files/getFileById?fileId=' + id;
    }
    public getRandomVideoBySeries(seriesId: number) {
        return this.baseUrl +`Files/getRandomFileBySeriesId?seriesId=${seriesId}&guid=${btoa(Math.random().toString()).substr(10, 15)}` ;
    }

    public getRandomVideoIdBySeries(seriesId: number) {
        return this.http.get<number>(this.baseUrl + `Files/getRandomFileIdBySeriesId?seriesId=${seriesId}`);

        // return this.baseUrl +`Files/getRandomFileBySeriesId?seriesId=${seriesId}&guid=${btoa(Math.random().toString()).substr(10, 15)}` ;
    }

    public getVideosBySeries(seriesId: number, count: number, isRandom: boolean, startId: number): Observable<Book[]> {
        return this.http.get<Book[]>( this.baseUrl +`Files/getFilesBySeries?id=${seriesId}&count=${count}&isRandom=${isRandom}&startId=${startId}`);
    }

    public getVideosBySeason(seasonId: number, count: number, isRandom: boolean, startId: number): Observable<Book[]> {
        return this.http.get<Book[]>( this.baseUrl +`Files/getFilesBySeason?id=${seasonId}&count=${count}&isRandom=${isRandom}&startId=${startId}`);
    }

    public setRating(id, rating) {
        var url = this.baseUrl + `files/rate/${id}`;
        return this.http.put(url, rating);
    }

    public setPosition(id, position) {
        var url = this.baseUrl + `files/updatePosition/${id}`;
        return this.http.put(url, position).subscribe();
    }

    public getBooks(): Observable<Book[]> {
        return this.http.get<Book[]>(this.baseUrl + `files`);
    }

    public filmWatched(id) {
        var url = this.baseUrl + `files/filmWatched/${id}`;
        return this.http.put(url, null);
    }

    public deleteBook(id: number) {
        return this.http.delete(this.baseUrl + 'files/' + id);
    }

    public getBookById(id): Observable<Book> {
        return this.http.get<Book>(this.baseUrl + 'files/' + id);
    }

    public searchFilesWithSeries(searchedValue: string, isRandom: boolean): Observable<Book[]> {
        return this.http.get<Book[]>(`${this.baseUrl}files/search-file-with-series/${encodeURIComponent(searchedValue)}/${isRandom}`);
    }

    public searchFilesWithSeason(seasonId: number, isRandom: boolean): Observable<Book[]> {
        return this.http.get<Book[]>(`${this.baseUrl}files/search-file-with-season/${seasonId}/${isRandom}`);
    }

    public searchFilesWithTitle(searchedValue: string): Observable<Book[]> {
        return this.http.get<Book[]>(`${this.baseUrl}files/search/${searchedValue}`);
    }
}
