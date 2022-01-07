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
import { Player } from '@vime/angular';

@Component({
  selector: 'app-player',
  templateUrl: './player.component.html',
  styleUrls: ['./player.component.css']
})
export class PlayerComponent implements OnInit {
  
  // @ViewChild('videoElement') video:ElementRef; 
  @ViewChild('player') player!: Player;

  public loaded: boolean;
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

    this.parameters = <PlayerParameters>(JSON.parse(JSON.stringify((<any>this.route.snapshot.queryParamMap).params)));
    // this.parameters = <PlayerParameters>((<any>this.route.snapshot.queryParamMap).params);

    // this.parameters = <PlayerParameters>history.state;

    this.setNextVideo(true);
    
    setInterval(() => this.updateStat(), 1000);
  }
  
  private getVideoElement():Player{
    return this.player;

    // if (this.video)
    //   return  (this.video.nativeElement as HTMLVideoElement);
  }
  
  public videoEnded() {
    console.log('ended');
    if(this.setNextVideo(true))
      console.log(true);
      // this.getVideoElement().play();

    // TODO - show end show screen
  }
  public skipVideo() {
      this.getVideoElement().currentTime =  this.getVideoElement().duration ;
      //this.setNextVideo(false);
      // this.getVideoElement().pause();
      // // this.getVideoElement().currentTime = 0;
      // this.videoURL ='';
      
      // this.getVideoElement().play();
      // // this.getVideoElement().load();
      // // this.getVideoElement().play();
      // // this.updateStat();
  }

  private setNextVideo(encreaseCounter:boolean) {
    if(this.parameters.videosCount <= this.playedVideoCount)
      return false;

      this.setUrl(this.service.getRandomVideoBySeries(this.parameters.seriesId));

      // if(this.parameters.videoId != 0){
      //   this.setUrl(this.service.getVideoURLById(this.parameters.videoId));
      //   this.parameters.videoId = 0;
      // }
      // else
      //   // this.setUrl(this.service.getVideoURLById(1797));
      //   this.setUrl(this.service.getRandomVideoBySeries(this.parameters.seriesId));

    if(encreaseCounter)
    {
      this.playedVideoCount++;

      var video = this.getVideoElement();
      if(video)
        this.previousVideoTimePlayed.seconds(video.currentTime);
    }

    // if(this.getVideoElement())
    // {
    //   this.getVideoElement().autoplay = true;
    //   this.getVideoElement().autoplay = false;
    // }
    return true;
  }

  private setUrl(url:string) {
		if(!this.loaded) {
			// assign url immediately on first assignment
			this.videoURL = url;
			this.loaded = true; 
		} else {
			// set url to null to remove player through ngIf, 
			//then assign new url in next tick to create new vime instance
			this.videoURL = null; 
			setTimeout(()=>{
				this.videoURL = url;
        setTimeout(()=>{
          
          if(this.getVideoElement())
            this.getVideoElement().play();
        },2000);
			},1);
		}
	}

  private updateStat() {
    var video = this.getVideoElement();
    var totalDuration = moment(this.previousVideoTimePlayed);
    if(video)
      totalDuration = totalDuration.seconds(video.currentTime);

    this.statStr = `Общее время просмотра ${totalDuration.format("mm:ss")} ${this.playedVideoCount}/${this.parameters.videosCount}`
  }
  
}

