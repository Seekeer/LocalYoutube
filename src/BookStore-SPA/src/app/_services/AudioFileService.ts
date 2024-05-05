import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';

import { Observable } from 'rxjs';
import { environment } from 'src/environments/environment';

import { AudioFile } from '../_models/Book';

@Injectable({
    providedIn: 'root'
})
export class AudioFileService {
    getCoverById(id: number) {
        return this.baseUrl +'AudioFiles/getImage?fileId=' + id;
    }
    
    moveToSeason(selectedFile: AudioFile, newId: number) {
      return this.http.post(`${this.baseUrl}AudioFiles/move-file-to-season/${selectedFile.id}/${newId}`, null).subscribe();
    }

    public updateTrack(audio: AudioFile) {

        const url = this.baseUrl +'AudioFiles/updateFile' ;
        this.http.post(url, audio).subscribe();
    }
    private baseUrl: string = environment.baseUrl + 'api/';

    constructor(private http: HttpClient) { }

    public getAudioURLById(id: number) {
        return this.baseUrl +'AudioFiles/getFileById?fileId=' + id;
    }

    public searchFilesWithSeries(seriesId: number, isRandom: boolean): Observable<AudioFile[]> {
        return this.http.get<AudioFile[]>( this.baseUrl +`AudioFiles/getFilesBySeries?id=${seriesId}&isRandom=${isRandom}`);
    }

    public searchFilesWithSeason(seasonId: number, isRandom: boolean): Observable<AudioFile[]> {
        return this.http.get<AudioFile[]>(`${this.baseUrl}AudioFiles/search-file-with-season/${seasonId}/${isRandom}`);
    }
    public downloadURL(seasonId: number): string {
        return `${this.baseUrl}AudioFiles/downloadSeason/${seasonId}`;
    }

    public searchFilesWithTitle(searchedValue: string): Observable<AudioFile[]> {
        return this.http.get<AudioFile[]>(`${this.baseUrl}AudioFiles/search/${searchedValue}`);
    }

    public searchRecentAudioFiles(): Observable<AudioFile[]> {
        return this.http.get<AudioFile[]>(`${this.baseUrl}AudioFiles/getLatest`);
    }
    
    public setPosition(id, position) {
        var url = this.baseUrl + `AudioFiles/setPosition/${id}`;
        return this.http.put(url, position).subscribe();
    }

    public deleteTrackById(id: number) {
        return this.http.delete(this.baseUrl + 'AudioFiles/' + id);
    }


}
