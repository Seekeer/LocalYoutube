import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';

import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';

import {
  Book,
  VideoType,
} from '../_models/Book';

@Injectable({
    providedIn: 'root'
})
export class FileService {
    public updateDownloaded() {
        return this.http.get<string>(`${this.baseUrl}update/updateDownloaded`);
    }
    public getFilmsByType(type: VideoType) {
        return this.http.get<Book[]>(`${this.baseUrl}files/getFileByType/${type}`);
    }
    public getSovietAnimation() {
        return this.http.get<Book[]>(`${this.baseUrl}files/getAnimation?isSoviet=true`);
    }
    getBigAnimation() {
        return this.http.get<Book[]>(`${this.baseUrl}files/getAnimation?isSoviet=false`);
    }
    private baseUrl: string = environment.baseUrl + 'api/';

    constructor(private http: HttpClient) { }

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

    public getVideosBySeries(seriesId: number, count: number, isRandom: boolean): Observable<Book[]> {
        return this.http.get<Book[]>( this.baseUrl +`Files/getFilesBySeries?id=${seriesId}&count=${count}&isRandom=${isRandom}`);
        // return this.http.get<Book[]>( this.baseUrl +`Files/getVideosBySeriesId?seriesId=${seriesId}&count=${count}`);
    }

    public addBook(book: Book) {
        return this.http.post(this.baseUrl + 'files', book);
    }

    public updateBook(id: number, book: Book) {
        return this.http.put(this.baseUrl + 'files/' + id, book);
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
        return this.http.delete(this.baseUrl + 'update/removeFile/?fileId=' + id);
    }

    public getBookById(id): Observable<Book> {
        return this.http.get<Book>(this.baseUrl + 'files/' + id);
    }

    public searchFilesWithSeries(searchedValue: string, isRandom: boolean): Observable<Book[]> {
        return this.http.get<Book[]>(`${this.baseUrl}files/search-file-with-series/${searchedValue}/${isRandom}`);
    }

    public searchFilesWithSeason(seasonId: number, isRandom: boolean): Observable<Book[]> {
        return this.http.get<Book[]>(`${this.baseUrl}files/search-file-with-season/${seasonId}/${isRandom}`);
    }

    public searchFilesWithTitle(searchedValue: string): Observable<Book[]> {
        return this.http.get<Book[]>(`${this.baseUrl}files/search/${searchedValue}`);
    }
}
