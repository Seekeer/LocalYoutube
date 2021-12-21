import { Component, ElementRef, OnInit, ViewChild } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { NgForm } from '@angular/forms';
import { Book } from 'src/app/_models/Book';
import { BookService } from 'src/app/_services/book.service';
import { ToastrService } from 'ngx-toastr';
import { CategoryService } from 'src/app/_services/category.service';

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

  constructor(public service: BookService,
    private categoryService: CategoryService,
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

