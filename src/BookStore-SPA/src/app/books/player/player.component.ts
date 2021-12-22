import { Component, ElementRef, OnInit, ViewChild } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { NgForm } from '@angular/forms';
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
export class PlayerComponent implements OnInit {
  
  @ViewChild('videoElement') video:ElementRef; 

  public formData: Book;
  public categories: any;
  public videoURL: string;
  public statStr: string;
  private previousVideoTimePlayed: Moment = moment.unix(0);
  
  playedVideoCount: number = 0;
  parameters: PlayerParameters;

  constructor(public service: FileService,
    private categoryService: SeriesService,
    private router: Router,
    private route: ActivatedRoute,
    private toastr: ToastrService) { }

  ngOnInit() {

    this.parameters = <PlayerParameters>history.state;

    this.setNextVideo(true);
    
    // setInterval(() => this.updateStat(), 1000);
  }
  
  private getVideoElement(){
    return  (this.video.nativeElement as HTMLVideoElement);
  }
  
  public videoEnded() {
    console.log('ended');
    if(this.setNextVideo(true))
      this.getVideoElement().play();
    // TODO - show end show screen
  }
  public skipVideo() {
    // this.setNextVideo(false);
    this.updateStat();
  }

  private setNextVideo(encreaseCounter:boolean) {
    if(this.parameters.videosCount <= this.playedVideoCount)
      return false;

      if(this.parameters.videoId != 0){
        this.videoURL = this.service.getVideoURLById(this.parameters.videoId);
        this.parameters.videoId = 0;
      }
      else
        this.videoURL = this.service.getRandomVideoBySeries(this.parameters.seriesId);

    if(encreaseCounter)
      this.playedVideoCount++;

    return true;
  }

  private updateStat() {
    var video = this.getVideoElement();
    var totalDuration = this.previousVideoTimePlayed;
    if(video)
      totalDuration = totalDuration.seconds(video.currentTime);

    this.statStr = `${totalDuration.format("mm:ss")} ${this.playedVideoCount}/${this.parameters.videosCount}`
  }
  
}

