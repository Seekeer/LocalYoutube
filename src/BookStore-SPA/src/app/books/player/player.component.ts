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

    // Get the query string value from our route
    const myArray = this.route.snapshot.queryParamMap.get('myArray');
    if (myArray === null) {
      this.arrayOfValues = new Array<number>();
    } else {
      this.arrayOfValues = JSON.parse(myArray);
    }

    console.log(this.arrayOfValues);

    // this.videoURL = this.service.getVideoURLById(1);
    this.setNextVideo();

    // this.resetForm();
    // let id;
    // this.route.params.subscribe(params => {
    //   id = params['id'];
    // });



    // if (id != null) {
    //   this.service.getBookById(id).subscribe(book => {
    //     this.formData = book;
    //     const publishDate =  new Date(book.publishDate);
    //     this.formData.publishDate = { year: publishDate.getFullYear(), month: publishDate.getMonth(), day: publishDate.getDay() };
    //   }, err => {
    //     this.toastr.error('An error occurred on get the record.');
    //   });
    // } else {
    //   this.resetForm();
    // }

    // this.categoryService.getCategories().subscribe(categories => {
    //   this.categories = categories;
    // }, err => {
    //   this.toastr.error('An error occurred on get the records.');
    // });
  }
  
  private getVideoElement(){
    return  (this.video.nativeElement as HTMLVideoElement);
  }
  public videoClick() {
    let videoEl =this.getVideoElement();

    if(videoEl.paused)
      videoEl.play();
    else
      videoEl.pause();
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

