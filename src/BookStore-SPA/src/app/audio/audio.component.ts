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
  Book,
} from '../_models/Book';
import { Serie } from '../_models/Category';
import { Seasons } from '../_models/Seasons';
import { AudioFileService } from '../_services/AudioFileService';
import { SeriesService } from '../_services/series.service';
import { MarkslistComponent } from '../markslist/markslist.component';

enum MenuAudioType {
  audioFairyTale,
  main,
}

@Component({
  selector: 'app-audio',
  templateUrl: './audio.component.html',
  styleUrls: ['./audio.component.css'],
})
export class AudioComponent implements OnInit {
  @ViewChild('audioElement') audio:ElementRef; 
  @ViewChild('markslist') child: MarkslistComponent;
  
  type: MenuAudioType;
  public isSelectSeries: boolean = true;
  public isChild: boolean = false;
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
  fileId: number;
  timer: any;
  forwardSpeed: number = 0;
  rewindSpeed: number = 0;

  constructor(
    private service: AudioFileService,
    private seriesService: SeriesService,
    private toastr: ToastrService,
    private spinner: NgxSpinnerService,
    private activatedRoute: ActivatedRoute
  ) {}

  ngOnInit(): void {
    setTimeout(() => this.showSpinner(), 5);

    this.type = MenuAudioType[this.activatedRoute.snapshot.paramMap.get('type')];

    this.displayListForType();
    this.intervalId = setInterval(() => this.updateStat(), 1000);
  }

  displayListForType() {
    switch (this.type) {
      case MenuAudioType.audioFairyTale: {
        this.isChild = true;
        this.getSeries(AudioType.FairyTale);
        break;
      }
      case MenuAudioType.main: {
        this.getSeries(null);
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

  setTimer() {
    if (this.interval) clearInterval(this.interval);

    this.timeLeft = this.timerMinutes * 60;

    this.interval = Number(
      setInterval(() => {
        if (this.timeLeft > 0) {
          this.timeLeft--;
        } else 
        {
          var el = this.getAudioElement();
          el.pause();
          this.setNextVideo();
        }
      }, 1000)
    );
  }

  timerMinutes: number;
  timerStr: string;
  timeLeft: number;
  private interval: number;

  public toFavorite(){
    this.seriesService.moveSeasonToFavorite(this.seasonId).subscribe();
  }

  public toBlackList(){
    this.seriesService.moveSeasonToBlackList(this.seasonId).subscribe();
    window.location.reload()
  }

  public deleteSeries(){
    this.seriesService.deleteSeason(this.seasonId).subscribe();
    this.seasons = this.seasons.filter(x => x.id != +this.seasonId);
    let serie = this.series.filter((x) => x.id == this.serieId)[0];
    serie.seasons = serie.seasons.filter(x => x.id != +this.seasonId);
    this.seasonId = null;

    this.search();
    // window.location.reload()
  }

  public deleteTrack(file: Book){
    this.service.deleteTrackById(file.id).subscribe(this.search.bind(this));
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
        .searchFilesWithSeries(serie.id, false)
        .subscribe(() =>{this.hideSpinner()}, this.getFilesError.bind(this));
    } else {
      this.toastr.error('Выберите название файла или сериала');
    }
  }
  
  openVideo(film: AudioFile) {
    throw new Error('Method not implemented.');
  }

  processFiles(files: AudioFile[]) {
    this.apiFiles = files;
    this.showFilteredBooks();
  }

  selectAudio(file: AudioFile) {
    this.currentIndex = file.index - 1;
    this.setNextVideo();
    // this.setVideoByIndex(file.index);
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

  forwardVideo() {
    this.updateCurrentTime(10);
  }
  rewindVideo() {
    this.updateCurrentTime(-10);
  }

  private updateCurrentTime(delta) {
      let isRewinding = delta < 0;
  
      if (isRewinding) {
        this.rewindSpeed = this.rewindSpeed + delta;
        this.forwardSpeed = 0;
      } else {
        this.forwardSpeed = this.forwardSpeed + delta;
        this.rewindSpeed = 0;
      }
  
      //clear the timeout
      clearTimeout(this.timer);
  
      let speed = isRewinding ? this.rewindSpeed : this.forwardSpeed;
      this.getAudioElement().currentTime =
        this.getAudioElement().currentTime + speed;
  
      //reset accumulator within 2 seconds of a double click
      this.timer = setTimeout(function () {
        this.rewindSpeed = 0;
        this.forwardSpeed = 0;
      }, 2000); // you can edit this delay value for the timeout, i have it set for 2 seconds
  }
  
  public continue() {
    for (let index = 0; index < this.apiFiles.length; index++) {
      const element = this.apiFiles[index];
      if(!element.isFinished && element.index)
      {
        this.setVideoByIndex(element.index);
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
  
  public episodesLeft: number = 1;
  
  private setNextVideo() {

    if(this.episodesLeft == 0)
      return;

    this.episodesLeft--;
    return this.setVideoByIndex(this.currentIndex+1);
  }
  private setVideoByIndex(index:number) {
    this.currentIndex = index;
    
    this.selectedFile = this.filteredFiles[this.currentIndex];
    this.fileId = this.selectedFile.id;
    this.audioURL = this.selectedFile.PlayURL;

    var el = this.getAudioElement();
    el?.load();

    this.position = this.selectedFile.currentPosition;
    this.setPosition();

    return true;
  }

  counter: number = 0;
}
