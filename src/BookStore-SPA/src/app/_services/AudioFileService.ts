import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';

import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';

import { AudioFile } from '../_models/Book';

@Injectable({
    providedIn: 'root'
})
export class AudioFileService {
    private baseUrl: string = environment.baseUrl + 'api/';

    constructor(private http: HttpClient) { }

    public getAudioURLById(id: number) {
        return this.baseUrl +'AudioFiles/getFileById?fileId=' + id;
    }

    public searchFilesWithSeries(searchedValue: string, isRandom: boolean): Observable<AudioFile[]> {
        return this.http.get<AudioFile[]>(`${this.baseUrl}AudioFiles/search-file-with-series/${encodeURIComponent(searchedValue)}/${isRandom}`);
    }

    public searchFilesWithSeason(seasonId: number, isRandom: boolean): Observable<AudioFile[]> {
        return this.http.get<AudioFile[]>(`${this.baseUrl}AudioFiles/search-file-with-season/${seasonId}/${isRandom}`);
    }

    public searchFilesWithTitle(searchedValue: string): Observable<AudioFile[]> {
        return this.http.get<AudioFile[]>(`${this.baseUrl}AudioFiles/search/${searchedValue}`);
    }
    
    public setPosition(id, position) {
        var url = this.baseUrl + `AudioFiles/updatePosition/${id}`;
        return this.http.put(url, position).subscribe();
    }

}