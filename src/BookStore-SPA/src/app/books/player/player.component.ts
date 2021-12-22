import { Component, ElementRef, OnInit, ViewChild } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { NgForm } from '@angular/forms';
import { Book } from 'src/app/_models/Book';
import { FileService } from 'src/app/_services/file.service';
import { ToastrService } from 'ngx-toastr';
import { SeriesService } from 'src/app/_services/series.service';

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
  arrayOfValues: number[];

  constructor(public service: FileService,
    private categoryService: SeriesService,
    private router: Router,
    private route: ActivatedRoute,
    private toastr: ToastrService) { }

  ngOnInit() {
    const myArray = this.route.snapshot.queryParamMap.get('myArray');
    if (myArray === null) {
      this.arrayOfValues = new Array<number>();
    } else {
      this.arrayOfValues = JSON.parse(myArray);
    }

    this.setNextVideo();

  }
  
  private getVideoElement(){
    return  (this.video.nativeElement as HTMLVideoElement);
  }
  
  public videoEnded() {
    console.log('ended');
    if(this.setNextVideo())
      this.getVideoElement().play();
    // TODO - show end show screen
  }
  
  private setNextVideo() {
    if(this.arrayOfValues.length == 0)
      return false;

    var id = this.arrayOfValues.pop();
    this.videoURL = this.service.getVideoURLById(id);

    return true;
  }
}

