import { Location } from '@angular/common';
import {
  Component,
  ElementRef,
  OnDestroy,
  OnInit,
  ViewChild,
} from '@angular/core';
import {
  ActivatedRoute,
  Router,
} from '@angular/router';

import * as moment from 'moment';
import { Moment } from 'moment';
import { ToastrService } from 'ngx-toastr';
import { Book } from 'src/app/_models/Book';
import { SeekPositionCollection } from 'src/app/_models/SeekPosition';
import { FileService } from 'src/app/_services/file.service';
import { SeriesService } from 'src/app/_services/series.service';
import { MarkslistComponent } from 'src/app/markslist/markslist.component';

import {
  MenuVideoType,
  PlayerParameters,
} from '../book-list/book-list.component';

@Component({
  selector: 'app-player',
  templateUrl: './player.component.html',
  styleUrls: ['./player.component.css'],
})
export class PlayerComponent implements OnInit, OnDestroy {
  @ViewChild('videoElement') video: ElementRef;
  @ViewChild('markslist') child: MarkslistComponent;

  public categories: any;
  public videoURL: string;
  public statStr: string;
  public isAdditionalBookmarksVisible: boolean;
  public name: string;
  private previousVideoTimePlayed: Moment = moment.unix(0);

  playedVideoCount: number = 0;
  public parameters: PlayerParameters;
  public videoId: number;

  videosList: number[] = [];
  currentVideoIndex: number = -1;
  intervalId: any;
  isRandom: boolean;
  isMobile: boolean;
  needToUpdateCurrentPosition: boolean;
  timerMinutes: number;
  timerStr: string;
  description: DescriptionRow[];
  descriptionCollapsed: boolean;
  totalDuration: moment.Moment;
  subscribed: boolean;
  lastVolumeChangedTime: Date = new Date(1);
  lastPositionUpdatedTime: Date = new Date(1);
  vlcPlayURL: string;
  notifications: NodeListOf<Element>;
  timer: any;
  forwardSpeed: number = 0;
  rewindSpeed: number = 0;
  rewindNotificationValue: any = document.querySelector(
    '.video-rewind-notify span'
  );
  forwardNotificationValue: any = document.querySelector(
    '.video-forward-notify span'
  );
  lastDoubleClickTime: Date;
  addMarkTimer: any;
  videoInfo: Book;
  isSovietAnimation: boolean;
  lastPosition: number;
  seekPositions: SeekPositionCollection = new SeekPositionCollection();
  checkPauseDurationTimer: any;
  enableDownload: boolean = true;
  isDownloading: boolean;

  constructor(
    public service: FileService,
    private categoryService: SeriesService,
    private router: Router,
    private location: Location,
    private route: ActivatedRoute,
    private toastr: ToastrService
  ) {}

  ngOnDestroy(): void {
    clearInterval(this.intervalId);
  }

  ngOnInit() {
    this.isMobile =
      /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
        navigator.userAgent
      );
    this.parameters = PlayerParameters.parse(
        JSON.stringify((<any>this.route.snapshot.queryParamMap).params));

    this.videoId = this.parameters.videoId;
    this.isSovietAnimation = this.parameters.type == MenuVideoType.sovietAnimation;
    
    this.isRandom = String(this.parameters.isRandom) === 'true';
    this.videosList.push(this.videoId);
    this.setNextVideo(true);

    if (this.parameters.seasonId == 0) {
      this.service
        .getVideosBySeries(
          this.parameters.seriesId,
          this.parameters.videosCount,
          this.isRandom,
          this.videoId
        )
        .subscribe(
          (videos) => {
            const selectedIds = videos
              .map(({ id }) => id)
              .filter((x) => x.toString() != this.videosList[0].toString());

            this.videosList = this.videosList.concat(selectedIds);
          },
          (err) => {
            console.log(
              `Cannot get video by series ${this.parameters.seriesId}`
            );
          }
        );
    } else {
      this.service
        .getVideosBySeason(
          this.parameters.seasonId,
          this.parameters.videosCount,
          this.isRandom,
          this.videoId
        )
        .subscribe(
          (videos) => {
            const selectedIds = videos
              .map(({ id }) => id)
              .filter((x) => x.toString() != this.videosList[0].toString());

            this.videosList = this.videosList.concat(selectedIds);
          },
          (err) => {
            console.log(
              `Cannot get video by season ${this.parameters.seriesId}`
            );
          }
        );
    }

    if(!this.isMobile)
      setTimeout(() => this.switchToFullscreen(), 2000);
      
    this.intervalId = setInterval(() => this.updateStat(), 1000);
  }

  private getVideoElement() {
    if (this.video) {
      var videoEl = this.video.nativeElement as HTMLMediaElement;

      this.rewindNotificationValue = document.querySelector(
        '.video-rewind-notify span'
      );
      this.forwardNotificationValue = document.querySelector(
        '.video-forward-notify span'
      );
      this.notifications = document.querySelectorAll('.notification');

      let that = this;
      this.notifications.forEach(function (notification) {
        notification.addEventListener('animationend', (e) =>
          that.animateNotificationOut(e)
        );
      });
      // videoEl.addEventListener('dblclick', (e) => {
      //   e.preventDefault(); });
      return videoEl;
    }
  }
  
  public videoPaused() {
    this.setTimerToCheckCurrentTimeOnBigStop(30);
  }

  setTimerToCheckCurrentTimeOnBigStop(numberOfSeconds:number){
    let that = this;
    that.checkPauseDurationTimer = setTimeout(function () {
        that.needToUpdateCurrentPosition = true;
    }, numberOfSeconds*1000);
  }

  public videoPlayed() {
    this.updateCurrentPositionAfterResumeIfNeed();
  }

  updateCurrentPositionAfterResumeIfNeed() {
    clearTimeout(this.checkPauseDurationTimer);
    let video = this.getVideoElement();

    if(!this.needToUpdateCurrentPosition)
      return;

    this.needToUpdateCurrentPosition = false;
    this.service.getPosition(this.videoId).subscribe(position => 
      {
        // If time changed for more then 10 seconds - update.
        if(Math.abs(video.currentTime - position) > 10)
          video.currentTime = position;
      });
  }

  public startPlay() {
    let that = this;

    if (this.addMarkTimer) return;

    this.addMarkTimer = setTimeout(function () {
      let video = that.getVideoElement();
      if (video.paused === false) video.pause();
      else video.play();

      that.addMarkTimer = null;
    }, 300);
  }

  public doubleClickHandler(e) {
    clearTimeout(this.addMarkTimer);
    this.addMarkTimer = null;

    e.preventDefault();
    const videoWidth = this.getVideoElement().offsetWidth;
    e.offsetX < videoWidth / 2 ? this.rewindVideo() : this.forwardVideo();
  }
  forwardVideo() {
    this.updateCurrentTime(15);
  }
  rewindVideo() {
    this.updateCurrentTime(-5);
  }
  
  
  moveToGood() {
    // TODO - HARDCODE
    this.moveToSeries(14);
  }
  moveToBad() {
    // TODO - HARDCODE
    this.moveToSeries(6107);
  }
  moveToSeries(serieId: number) {
    this.service.setSeriesId(serieId, this.videoId).subscribe();
  }
  
  public showMoveModal() {
    const dialog = <any>document.getElementById('moveDialog');
    dialog.showModal();
  }

  public moveFilm(toBad: boolean) {
    const dialog = <any>document.getElementById('moveDialog');
    dialog.close();

    if (toBad) {
      this.moveToBad();
    }
    else
      this.moveToGood();
  }

  private animateNotificationOut(event: Event) {
    this.notifications.forEach((x) => x.classList.remove('animate-in'));
  }

  private updateCurrentTime(delta) {
   
    this.getVideoElement().currentTime =
      this.getVideoElement().currentTime + delta;
  }

  public animateNotificationIn(isRewinding: boolean) {
    isRewinding
      ? this.notifications[0].classList.add('animate-in')
      : this.notifications[1].classList.add('animate-in');
  }

  public showDeleteModal() {
    const dialog = <any>document.getElementById('favDialog');
    dialog.showModal();
  }

  public deleteFilm(deleteFilm: boolean) {
    const dialog = <any>document.getElementById('favDialog');
    dialog.close();

    if (deleteFilm) {
      this.location.back();
      this.service.deleteBook(this.videoId).subscribe();
    }
  }

  public videoEnded() {
    console.log('ended');
    if (this.setNextVideo(true)) this.getVideoElement().load();
    // TODO - show end show screen
  }

  public seeking(ev:any){
    console.log(ev);
    var video = this.getVideoElement();

    this.seekPositions.TryAddPosition(this.lastPosition, video.currentTime);
  }

  public download() {
    (window as any).open(this.videoURL,'_blank');
  }

  public copyLink() {
    this.copyToClipboard(this.videoURL);
    // navigator.clipboard.writeText(this.videoURL).then().catch(e => console.error(e));
  }

  private copyToClipboard(text) {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text);
    } else {
      alert(text);
    }
  }

  public skipVideo() {
    this.service.setRating(this.videoId, -1).subscribe();
    this.getVideoElement().pause();
    this.getVideoElement().currentTime = 0;
    this.videoURL = '';
    this.getVideoElement().load();

    if (this.setNextVideo(false)) this.getVideoElement().load();
    // this.getVideoElement().play();
    // this.updateStat();
  }

  setTimer() {
    if (this.interval) clearInterval(this.interval);

    this.timeLeft = this.timerMinutes * 60;

    this.interval = Number(
      setInterval(() => {
        if (this.timeLeft > 0) {
          this.timeLeft--;
        } else this.setNextVideo(true);
      }, 1000)
    );
  }

  timeLeft: number;
  private interval: number;

  public showAdditionalBookmarks() {
    this.isAdditionalBookmarksVisible = ! this.isAdditionalBookmarksVisible;
  }

  public switchToFullscreen() {
    var el = this.getVideoElement();
    
    try{
      if (el && el.requestFullscreen) el.requestFullscreen();
    }
    catch(exception){}
  }

  private setNextVideo(encreaseCounter: boolean) {
    console.log(`Video ended ${this.videoURL} ${this.name}`);
    this.isDownloading = false;
    if (this.parameters.videosCount <= this.playedVideoCount) {
      this.videoURL = null;
      if(this.parameters.showDeleteButton == true)
        this.showDeleteModal();
      else if(this.isSovietAnimation)
        this.showMoveModal();
      return false;
    }

    var el = this.getVideoElement();
    let currentId = this.videosList[++this.currentVideoIndex];
    this.videoId = currentId;

    this.videoURL = this.service.getVideoURLById(currentId);
    if (el)
      el.src = this.videoURL;
    this.vlcPlayURL = `vlc://${this.videoURL}`;
    if(el?.attributes.getNamedItem("autoplay") === null)
      el?.setAttribute("autoplay","");
    el?.load();

    if (encreaseCounter) {
      this.playedVideoCount++;

      var video = this.getVideoElement();
      if (video) this.previousVideoTimePlayed = this.totalDuration.clone();
    }

    this.service.getBookById(currentId).subscribe(
      (videoInfo) => {
        this.name = videoInfo.displayName;
        this.videoInfo = videoInfo;
        this.description = this.parseDescription(videoInfo.description);
      },
      (err) => {
        console.log(`Cannot get video by series ${this.parameters.seriesId}`);
      }
    );

    return true;
  }

  public markClicked(row: DescriptionRow) {
    this.child.rowClicked(row);
  }

  parseDescription(description: string): DescriptionRow[] {
    if(!description)
      return [];

    let paragraphs = description.split(/\r\n|\n\r|\n|\r/).map(paragraph => {
        let convertedWords = paragraph.trim().split(" ");
        const firstWord = convertedWords[0];
        if(firstWord.indexOf(':') == -1)
          return new DescriptionRow( paragraph, null);
        
        return new DescriptionRow( paragraph.replace(firstWord,''), firstWord) ;
      });

    return paragraphs;
  }
  
  convertDescriptionToHtml(description: string): string {
    let paragraphs = description.split(/\r\n|\n\r|\n|\r/).map(paragraph => {
      let convertedWords = paragraph.split(" ").map(word => {
        if(word.indexOf(':') == -1)
          return word;

        return `<a  (click)="markClicked(${word})">${word}</a>`;

      });

      return convertedWords.join(' ');
    
  });
  return paragraphs.join('\n\r');
}
  

  private updateStat() {
    var video = this.getVideoElement();

    if (!video || video.paused) return;

    this.setPosition();

    this.totalDuration = moment(this.previousVideoTimePlayed);
    if (video) {
      this.totalDuration = this.totalDuration.add(video.currentTime, 'seconds');

      if (video.currentTime > 10)
      {
        this.lastPosition = video.currentTime;

        if(!this.needToUpdateCurrentPosition)
          this.updateServerPosition(video.currentTime);
      }
    }

    if (this.totalDuration.seconds() - video.currentTime > 2)
      this.statStr = `Общее время просмотра всех серий ${this.totalDuration.format(
        'mm:ss'
      )} ${this.playedVideoCount}/${this.parameters.videosCount}`;
  }
  updateServerPosition(currentTime: number) {
    var msFromLastUpdate = (new Date()).valueOf() - this.lastPositionUpdatedTime.valueOf() ;
    if ( msFromLastUpdate< 900 )
      return;
    
    this.service.setPosition(this.videoId, currentTime);
    this.lastPositionUpdatedTime = new Date();
  }

  setPosition() {
    if(!this.videoInfo)
      return;

    this.tryToDownload();

    const position = this.videoInfo.currentPosition;
    var video = this.getVideoElement();
    if (video.duration && position > 0 && video) {

      if(Math.abs(video.duration - position) < 30)
      {
        video.pause();
      }
      video.currentTime = position;
      this.videoInfo = null;
      video.play();
    }
  }
  tryToDownload() {
    
    if(this.videoInfo.durationMinutes > 60 || this.isDownloading )
      return;
    this.isDownloading = true;
    setTimeout(function () {
      if(this.enableDownload)
        this.startDownload();
    }.bind(this), 25000, );
  }

  startDownload() {
    var req = new XMLHttpRequest();
    req.open('GET', this.videoURL, true);
    req.responseType = 'blob';

    let that = this;

    console.log('start load');

    req.onload = function() {
      // Onload is triggered even on 404
      // so we need to check the status code
      if (this.status === 200) {

        var videoBlob = this.response;
        that.setBlobAsSurce(videoBlob);
      }
    }
    req.onerror = function() {
      // Error
    }

    req.send();
  }
  setBlobAsSurce(videoBlob: any) {
    // that.saveFile(videoBlob);
    var vid = URL.createObjectURL(videoBlob); // IE10+
    let videoEl = this.getVideoElement();
    let isPlaying = this.videoIsPlaying(videoEl);
    videoEl.removeAttribute("autoplay");
    videoEl.src = vid;
    videoEl.currentTime = this.lastPosition;
    if(isPlaying)
      videoEl.play();
  }

  videoIsPlaying(videoEl: HTMLMediaElement) {
    return !!(videoEl.currentTime > 0 && !videoEl.paused && !videoEl.ended && videoEl.readyState > 2);
  }

  // saveFile(videoBlob: Blob) {
  //   var file = new File([videoBlob], this.videoId.toString());
  //   try {
  //     // Specify the filename using the File constructor, but ...
  //     file = new File(videoBlob, this.videoId.toString());
  //   } catch (e) {
  //     // ... fall back to the Blob constructor if that isn't supported.
  //     // file = new Blob(videoBlob);
  //   }
    
  //   var url = URL.createObjectURL(file);
  //   this.getVideoElement().src = file;
  // }
}

export class DescriptionRow {

  constructor(public caption: string, public timestamp: string) {}

  getPosition(): number {
    let hours: string = '0', minutes: string, seconds: string;
    if(this.countInstances(this.timestamp, ':') == 2)
      [hours, minutes, seconds] = this.timestamp.split(':');
    else
      [minutes, seconds] = this.timestamp.split(':');

    return +seconds + +minutes * 60 + +hours * 60 * 60;
  }
  
  countInstances(string, substring) {
    return string.split(substring).length - 1;
 }
}

