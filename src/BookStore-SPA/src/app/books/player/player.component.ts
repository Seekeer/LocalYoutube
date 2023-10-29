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
import { Mark } from 'src/app/_models/Mark';
import { FileService } from 'src/app/_services/file.service';
import { SeriesService } from 'src/app/_services/series.service';
import { MarkslistComponent } from 'src/app/markslist/markslist.component';

import { PlayerParameters } from '../book-list/book-list.component';

@Component({
  selector: 'app-player',
  templateUrl: './player.component.html',
  styleUrls: ['./player.component.css'],
})
export class PlayerComponent implements OnInit, OnDestroy {
  @ViewChild('videoElement') video: ElementRef;
  @ViewChild('markslist') child: MarkslistComponent;

  public formData: Book;
  public categories: any;
  public videoURL: string;
  public statStr: string;
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
  timerMinutes: number;
  timerStr: string;
  totalDuration: moment.Moment;
  subscribed: boolean;
  lastVolumeChangedTime: Date = new Date(1);
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
    this.parameters = <PlayerParameters>(
      JSON.parse(
        JSON.stringify((<any>this.route.snapshot.queryParamMap).params)
      )
    );

    this.videoId = this.parameters.videoId;
    
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
    this.updateCurrentTime(10);
    this.animateNotificationIn(false);
  }
  rewindVideo() {
    this.updateCurrentTime(-10);
    this.animateNotificationIn(true);
  }
  private animateNotificationOut(event: Event) {
    this.notifications.forEach((x) => x.classList.remove('animate-in'));
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
    this.getVideoElement().currentTime =
      this.getVideoElement().currentTime + speed;

    let NotificationValue = isRewinding
      ? this.rewindNotificationValue
      : this.forwardNotificationValue;
    NotificationValue.innerHTML = `${Math.abs(speed)} seconds`;

    //reset accumulator within 2 seconds of a double click
    this.timer = setTimeout(function () {
      this.rewindSpeed = 0;
      this.forwardSpeed = 0;
    }, 2000); // you can edit this delay value for the timeout, i have it set for 2 seconds
  }

  public animateNotificationIn(isRewinding: boolean) {
    isRewinding
      ? this.notifications[0].classList.add('animate-in')
      : this.notifications[1].classList.add('animate-in');
  }

  public calculateDisplayTime(mark: Mark) {
    let minutes = Math.floor(mark.position / 60);
    let seconds = Math.floor(mark.position - minutes * 60);

    let minutesStr = minutes.toString().padStart(2, '0');
    let secondsStr = seconds.toString().padStart(2, '0');

    mark.displayTime = `${minutesStr}:${secondsStr}`;
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

  public switchToFullscreen() {
    var el = this.getVideoElement();

    if (el && el.requestFullscreen) el.requestFullscreen();
  }

  private setNextVideo(encreaseCounter: boolean) {
    console.log(`Video ended ${this.videoURL} ${this.name}`);

    if (this.parameters.videosCount <= this.playedVideoCount) {
      this.videoURL = null;
      if(this.parameters.showDeleteButton)
        this.showDeleteModal()
      return false;
    }

    let currentId = this.videosList[++this.currentVideoIndex];
    this.videoId = currentId;
    
    this.videoURL = this.service.getVideoURLById(currentId);
    //this.download();
    this.vlcPlayURL = `vlc://${this.videoURL}`;
    var el = this.getVideoElement();
    el?.load();

    if (encreaseCounter) {
      this.playedVideoCount++;

      var video = this.getVideoElement();
      if (video) this.previousVideoTimePlayed = this.totalDuration.clone();
    }

    this.service.getBookById(currentId).subscribe(
      (videoInfo) => {
        this.name = videoInfo.displayName;
        this.setPosition(videoInfo.currentPosition);

      },
      (err) => {
        console.log(`Cannot get video by series ${this.parameters.seriesId}`);
      }
    );

    return true;
  }

  private updateStat() {
    var video = this.getVideoElement();


    if (!video || video.paused) return;

    this.totalDuration = moment(this.previousVideoTimePlayed);
    if (video) {
      this.totalDuration = this.totalDuration.add(video.currentTime, 'seconds');

      if (video.currentTime > 10)
        this.service.setPosition(this.videoId, video.currentTime);
    }

    if (this.totalDuration.seconds() - video.currentTime > 2)
      this.statStr = `Общее время просмотра всех серий ${this.totalDuration.format(
        'mm:ss'
      )} ${this.playedVideoCount}/${this.parameters.videosCount}`;
  }

  setPosition(position: number) {
    var video = this.getVideoElement();
    if (position > 0 && video) {
      video.currentTime = position;
    }
  }
}
