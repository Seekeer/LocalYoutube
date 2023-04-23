import {
  Component,
  ElementRef,
  OnInit,
  ViewChild,
} from '@angular/core';
import { SafeHtml } from '@angular/platform-browser';
import { ActivatedRoute } from '@angular/router';

import { NgxSpinnerService } from 'ngx-spinner';
import { ToastrService } from 'ngx-toastr';

import {
  AudioFile,
  AudioType,
} from '../_models/Book';
import { Serie } from '../_models/Category';
import { Seasons } from '../_models/Seasons';
import { AudioFileService } from '../_services/AudioFileService';
import { SeriesService } from '../_services/series.service';

@Component({
  selector: 'app-audio',
  templateUrl: './audio.component.html',
  styleUrls: ['./audio.component.css'],
})
export class AudioComponent implements OnInit {
  @ViewChild('audioElement') audio:ElementRef; 
  type: string;
  public isSelectSeries: boolean = true;
  public series: Serie[];
  searchTitle: string;
  seasonId: number;
  serieId: number;
  apiFiles: AudioFile[];
  filteredFiles: AudioFile[];
  position: number;
  currentIndex: number = -1;
  intervalId: any;
  selectedFile: AudioFile;
  audioURL: SafeHtml;
  seasons: Seasons[];

  constructor(
    private service: AudioFileService,
    private seriesService: SeriesService,
    private toastr: ToastrService,
    private spinner: NgxSpinnerService,
    private activatedRoute: ActivatedRoute
  ) {}

  ngOnInit(): void {
    console.log('audio');
    setTimeout(() => this.showSpinner(), 5);

    this.type = this.activatedRoute.snapshot.paramMap.get('type');

    this.displayListForType();
    this.intervalId = setInterval(() => this.updateStat(), 1000);
  }

  displayListForType() {
    switch (this.type) {
      case 'main': {
        this.getSeries(AudioType.FairyTale);
        break;
      }
    }
  }

  getSeries(type: AudioType) {
    this.seriesService.getAllAudio(type).subscribe((series) => {
      this.series = series.sort((a, b) => {
        return a.name >= b.name ? 1 : -1;
      });
      this.hideSpinner();
    });
  }

  public search() {
    this.showSpinner();
    this.currentIndex = -1;

    if (this.searchTitle ) {
      this.service
        .searchFilesWithTitle(this.searchTitle)
        .subscribe(this.processFiles.bind(this), this.getFilesError.bind(this));
    } else if (this.seasonId ) {
      this.service
        .searchFilesWithSeason(this.seasonId, false)
        .subscribe(this.processFiles.bind(this), this.getFilesError.bind(this));
    } else if (this.serieId) {
      let serie = this.series.filter((x) => x.id == this.serieId)[0];
      this.seasons = serie.seasons;
      this.service
        .searchFilesWithSeries(serie.name, false)
        .subscribe(this.processFiles.bind(this), this.getFilesError.bind(this));
    } else {
      this.toastr.error('Выберите название файла или сериала');
    }
  }

  continueWatch() {
    var film = this.filteredFiles.find((x) => !x.isFinished);

    this.openVideo(film);
  }

  openVideo(film: AudioFile) {
    throw new Error('Method not implemented.');
  }

  processFiles(files: AudioFile[]) {
    this.apiFiles = files;
    this.showFilteredBooks();
  }

  selectAudio(file: AudioFile) {
    this.setVideoByIndex(file.index);
  }

  showFilteredBooks() {

    this.apiFiles.forEach((element,index) => {
      element.PlayURL = this.service.getAudioURLById(element.id);
      element.index = index;
    });

    this.filteredFiles = this.apiFiles;

    this.hideSpinner();

    this.selectedFile = new AudioFile();
    // this.videoEnded();
  }

  getFilesError(error) {
    this.hideSpinner();
    this.filteredFiles = [];
  }

  public showSpinner() {
    this.counter++;

    this.spinner.show();
  }

  hideSpinner() {
    setTimeout(() => {
      this.counter--;

      if (this.counter < 0) this.counter = 0;

      if (this.counter == 0) this.spinner.hide();
    }, 5);
  }
  

  private updateStat() {
    var video = this.getAudioElement();

    if(video.currentTime > 10 && this.selectedFile)
      this.service.setPosition(this.selectedFile.id, video.currentTime);

    // this.setPosition();
  }

  private getAudioElement(){
    if (this.audio)
      return  (this.audio.nativeElement as HTMLAudioElement);
  }

  setPosition() {
    var video = this.getAudioElement();
    if(this.position >0 && video){
      video.currentTime = this.position;
      this.position = -1;
    }
  }
  
  public continue() {
    for (let index = 0; index < this.apiFiles.length; index++) {
      const element = this.apiFiles[index];
      if(!element.isFinished && element.index)
      {
        this.setVideoByIndex(element.index);
        this.position = element.currentPosition;
        this.setPosition();
        return;
      }
    }

    this.setVideoByIndex(0);
  }

  public videoEnded() {
    console.log('ended');
    if(this.setNextVideo())
      this.getAudioElement().load();
  }
  
  private setNextVideo() {

    return this.setVideoByIndex(this.currentIndex+1);
  }
  private setVideoByIndex(index:number) {
    this.currentIndex = index;

    this.selectedFile = this.filteredFiles[this.currentIndex];
    this.audioURL = this.selectedFile.PlayURL;

    var el = this.getAudioElement();
    el?.load();

    return true;
  }

  counter: number = 0;
}
