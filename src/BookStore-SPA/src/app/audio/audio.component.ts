import {
  Component,
  ElementRef,
  OnInit,
  ViewChild,
} from '@angular/core';
import { SafeHtml } from '@angular/platform-browser';
import { ActivatedRoute } from '@angular/router';

import * as moment from 'moment';
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
import { FileService } from '../_services/file.service';
import { SeriesService } from '../_services/series.service';
import { MarkslistComponent } from '../markslist/markslist.component';

enum MenuAudioType {
  audioFairyTale,
  сhildMusic,
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
  public showChoicePanel: boolean = true;
  public showManagementButtons: boolean = false;
  public series: Serie[];
  public episodesLeft: number = 1;
  public trackCaption: string;
  public trackInfo: string;
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
  allSeasons: Seasons[];
  fileId: number;
  newSeasonId: number;
  timer: any;
  forwardSpeed: number = 0;
  rewindSpeed: number = 0;
  showCover: boolean;
  addMarkTimer: any;

  constructor(
    private service: AudioFileService,
    private videoService: FileService,
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

    this.service
      .searchRecentAudioFiles()
      .subscribe(this.processFiles.bind(this), this.getFilesError.bind(this));
  }

  displayListForType() {
    switch (this.type) {
      case MenuAudioType.audioFairyTale: {
        this.isChild = true;
        this.showManagementButtons = true;
        this.getSeries(AudioType.FairyTale);
        break;
      }
      case MenuAudioType.сhildMusic: {
        this.isChild = true;
        this.showCover = true;
        this.getSeries(AudioType.ChildMusic);
        break;
      }
      case MenuAudioType.main: {
        this.episodesLeft = 100;
        this.getSeries(null);
        break;
      }
    }
  }

  getSeries(type: AudioType) {
    this.seriesService.getAllAudioSeries(type).subscribe((series) => {
      this.series = series.sort((a, b) => {
        return a.name >= b.name ? 1 : -1;
      });

      this.allSeasons = series.reduce((pr, cur) => [...pr, ...cur.seasons], []).sort((a, b) => {
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

  public fileChanged(newValue:string){
    this.selectedFile.name = newValue;

    this.service.updateTrack(this.selectedFile);
  }

  public changeSeason(){

    this.service.moveToSeason(this.selectedFile, this.newSeasonId);
  }

  timerMinutes: number;
  timerStr: string;
  timeLeft: number;
  private interval: number;

  public toFavorite(){
    this.moveToFavorite(this.selectedFile);
  }

  public toBlackList(){
    this.moveToBlacklist(this.selectedFile);
  }

  public moveToFavorite(file: Book){
    this.seriesService.moveSeasonToFavorite(file.seasonId).subscribe();
  }

  public moveToBlacklist(file: Book){
    this.seriesService.moveSeasonToBlackList(file.seasonId).subscribe();
    window.location.reload();
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
      this.seasons = serie.seasons.sort((a, b) => {
        return a.name >= b.name ? 1 : -1;
      });
      if(this.seasons.length == 1){
        this.seasonId = this.seasons[0].id;
        this.search();
        this.hideSpinner();
      }
      else{
        this.service
        .searchFilesWithSeries(serie.id, false)
        .subscribe(this.sortFilesByDuration.bind(this), this.getFilesError.bind(this));
      }

    } else {
      this.toastr.error('Выберите название файла или сериала');
    }
  }
  
  openBook(film: AudioFile) {
    this.seasonId = film.seasonId;
    this.search();
    this.continue();
  }

  sortFilesByDuration(files: AudioFile[]) {
    this.processFilesBase(files, true);
  }

  processFiles(files: AudioFile[]) {
    this.processFilesBase(files, false);
  }

  updateSeasonNames(apiFiles: AudioFile[]) {
    apiFiles.forEach(file => file.seasoName = this.allSeasons.filter(x => x.id == file.seasonId)[0]?.name);
  }

  processFilesBase(files: AudioFile[],  sortByDuration: boolean) {
    this.apiFiles = sortByDuration ? files.sort( (x,y) => x.durationMinutes - y.durationMinutes ) : files;
    this.updateSeasonNames(this.apiFiles);
    
    this.showFilteredBooks();
  }

  selectAudio(file: AudioFile) {
    this.currentIndex = file.index - 1;
    this.newSeasonId = file.seasonId;
    this.setNextVideo();
    // this.setVideoByIndex(file.index);
  }

  showFilteredBooks() {

    this.apiFiles.forEach((element,index) => {
      element.PlayURL = this.service.getAudioURLById(element.id);
      element.coverURL = (`${this.service.getCoverById(element.id)}`);
      element.index = index;
    });

    this.filteredFiles = this.apiFiles;
    if(this.type == MenuAudioType.сhildMusic)
      this.filteredFiles = this.apiFiles.sort(() => Math.random() - 0.5);

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

    this.updateTrackInfo();
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

  public startPlay() {
    let that = this;

    if (this.addMarkTimer) return;

    this.addMarkTimer = setTimeout(function () {
      let video = that.getAudioElement();
      if (video.paused === false) video.pause();
      else video.play();

      that.addMarkTimer = null;
    }, 300);
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
      if(!element.isFinished)
      {
        this.setVideoByIndex(element.index);
        this.showChoicePanel = false;
        return;
      }
    }

    this.setVideoByIndex(0);
  }

  public videoEnded() {
    this.service.setPosition(this.selectedFile.id, (this.selectedFile.durationMinutes + 1) *60);
    this.position = 0;

    if(this.setNextVideo())
      this.getAudioElement().load();
  }
  
  private setNextVideo() {

    if(this.episodesLeft == 0)
    {
      alert('Нельзя выбрать ещё одну сказку!');
      return;
    }

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

    if(!this.selectedFile.isFinished && this.shouldResume())
      this.position = this.selectedFile.currentPosition;

    this.setPosition();

    this.trackCaption = this.selectedFile.name;
    this.updateTrackInfo();
    return true;
  }

  shouldResume() {
    return this.type != MenuAudioType.сhildMusic;
  }

  download() {
    (window as any).open(this.service.downloadURL(this.seasonId),'_blank');
  }

  updateTrackInfo() {
    if(!this.selectedFile)
      return;

    var time =  this.selectedFile.previousFilesDurationSeconds + this.position;
    var totalTime = this.filteredFiles[ this.filteredFiles.length - 1].previousFilesDurationSeconds ;
    var percent = time == 0 || Number.isNaN(time) ? 0 : time/totalTime*100;
    var timeMoment = moment(0).utc(false).add(time, 'seconds');
    var totalTimeMoment = moment(0).utc(false).add(totalTime, 'seconds');
    this.trackInfo = `Прослушано ${(percent).toFixed(0)}% ${timeMoment.format('HH:mm:ss')} из ${totalTimeMoment.format('HH:mm:ss')}`;
  }

  counter: number = 0;
}
