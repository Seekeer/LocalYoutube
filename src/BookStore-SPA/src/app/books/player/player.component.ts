import { Component, ElementRef, OnDestroy, OnInit, ViewChild } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { NgForm, NumberValueAccessor } from '@angular/forms';
import { Book } from 'src/app/_models/Book';
import { FileService } from 'src/app/_services/file.service';
import { ToastrService } from 'ngx-toastr';
import { SeriesService } from 'src/app/_services/series.service';
import { PlayerParameters } from '../book-list/book-list.component';
import { Moment } from 'moment';
import * as moment from 'moment';

@Component({
  selector: 'app-player',
  templateUrl: './player.component.html',
  styleUrls: ['./player.component.css']
})
export class PlayerComponent implements OnInit, OnDestroy {
  
  @ViewChild('videoElement') video:ElementRef; 

  public formData: Book;
  public categories: any;
  public videoURL: string;
  public statStr: string;
  private previousVideoTimePlayed: Moment = moment.unix(0);
  
  playedVideoCount: number = 0;
  parameters: PlayerParameters;
  videoId: number;

  videosList: number[] = [];
  currentVideoIndex: number = -1;
  intervalId: any;
  position: number;

  constructor(public service: FileService,
    private categoryService: SeriesService,
    private router: Router,
    private route: ActivatedRoute,
    private toastr: ToastrService) { }

  ngOnDestroy(): void {
    clearInterval(this.intervalId);
  }

  ngOnInit() {

    this.parameters = <PlayerParameters>(JSON.parse(JSON.stringify((<any>this.route.snapshot.queryParamMap).params)));

    this.videoId = this.parameters.videoId;
    this.position = parseFloat(this.parameters.position.toString());
    this.videosList.push(this.videoId);
    this.setNextVideo(true);

    this.service.getVideosBySeries(this.parameters.seriesId, this.parameters.videosCount).subscribe((videos) => {
      const selectedIds = videos.map(({ id }) => id).filter(x => x.toString() != this.videosList[0].toString());

      this.videosList = this.videosList.concat(selectedIds);
    },
      err => {
        console.log(`Cannot get video by series ${this.parameters.seriesId}`);
      })

    // setTimeout(() => this.updateStat(), 1000);
    this.intervalId = setInterval(() => this.updateStat(), 1000);
  }
  
  private getVideoElement(){
    if (this.video)
      return  (this.video.nativeElement as HTMLVideoElement);
  }
  
  public videoEnded() {
    console.log('ended');
    if(this.setNextVideo(true))
      this.getVideoElement().load();
    // TODO - show end show screen
  }
  public skipVideo() {
      this.service.setRating(this.videoId, -1).subscribe();
      this.getVideoElement().pause();
      this.getVideoElement().currentTime = 0;
      this.videoURL ='';
      this.getVideoElement().load();

      if(this.setNextVideo(false))
        this.getVideoElement().load();
      // this.getVideoElement().play();
      // this.updateStat();
  }

  private setNextVideo(encreaseCounter:boolean) {
    if(this.parameters.videosCount <= this.playedVideoCount){
      this.videoURL = null;
      return false;
    }

    let currentId = this.videosList[++this.currentVideoIndex];

    this.videoURL = this.service.getVideoURLById(currentId);
    var el = this.getVideoElement();
    el?.load();

      // if(this.parameters.videoId != 0){
      //   this.videoURL = this.service.getVideoURLById(this.parameters.videoId);
      //   this.parameters.videoId = 0;
      // }
      // else
      // this.service.getRandomVideoIdBySeries(this.parameters.seriesId).subscribe((id) => {
      //   this.videoId = id;
      //   this.videoURL = this.service.getVideoURLById(id);
      //   this.getVideoElement().load();
      // },
      //   err => {
      //     console.log(`Cannot get video by series ${this.parameters.seriesId}`);
      //   })
      //   // this.videoURL = this.service.getRandomVideoBySeries(this.parameters.seriesId);

    if(encreaseCounter)
    {
      this.playedVideoCount++;

      var video = this.getVideoElement();
      if(video)
        this.previousVideoTimePlayed.seconds(video.currentTime);
    }

    return true;
  }

  private updateStat() {
    var video = this.getVideoElement();

    this.setPosition();
    
    var totalDuration = moment(this.previousVideoTimePlayed);
    if(video)
      totalDuration = totalDuration.seconds(video.currentTime);

      this.service.setPosition(this.videoId, video.currentTime);

    this.statStr = `Общее время просмотра ${totalDuration.format("mm:ss")} ${this.playedVideoCount}/${this.parameters.videosCount}`
  }
  setPosition() {
    var video = this.getVideoElement();
    if(this.position>0 && video){
      video.currentTime = this.position;
      this.position = -1;
    }
  }
  
}

