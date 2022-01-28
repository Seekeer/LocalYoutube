import { Component, ElementRef, OnInit, ViewChild } from '@angular/core';
import { NavigationExtras, Router } from '@angular/router';
import { FileService } from 'src/app/_services/file.service';
import { ToastrService } from 'ngx-toastr';
import { ConfirmationDialogService } from 'src/app/_services/confirmation-dialog.service';
import { Subject } from 'rxjs';
import { debounceTime } from 'rxjs/operators';
import { HttpClient } from '@angular/common/http';
import { SeriesService } from 'src/app/_services/series.service';
import { Serie } from 'src/app/_models/Category';
import { Book, Book as VideoFile } from 'src/app/_models/Book';


@Component({
  selector: 'app-book-list',
  templateUrl: './book-list.component.html',
  styleUrls: ['./book-list.component.css']
})
export class BookListComponent implements OnInit {
  @ViewChild('videoElement') video:ElementRef; 
  
  public books: VideoFile[];
  public listComplet: any;
  public isRandom: boolean = true;
  public searchTerm: string;
  public episodeCount: number = 1;
  public searchValueChanged: Subject<string> = new Subject<string>();
  public series: Serie[];

  constructor(private router: Router,
              private service: FileService,
              private seriesService: SeriesService,
              private toastr: ToastrService,
              private http:HttpClient,
              private confirmationDialogService: ConfirmationDialogService) { }

  ngOnInit() {
    this.getSeries();

    this.searchValueChanged.pipe(debounceTime(1000))
    .subscribe(() => {
      this.search();
    });
  }
  getSeries() {
    
    this.seriesService.getAll().subscribe(series => {
      this.series =series;
    });
  }

  public addBook() {
    this.router.navigate(['/book']);
  }

  public editBook(bookId: number) {
    this.router.navigate(['/book/' + bookId]);
  }

  public deleteBook(bookId: number) {
    this.confirmationDialogService.confirm('Atention', 'Do you really want to delete this book?')
      .then(() =>
        this.service.deleteBook(bookId).subscribe(() => {
          this.toastr.success('The book has been deleted');
          // this.getValues();
        },
          err => {
            this.toastr.error('Failed to delete the book.');
          }))
      .catch(() => '');
  }

  public searchBooks() {
    this.searchValueChanged.next();
  }

  private search() {
    if (this.searchTerm !== '') {
      this.service.searchFilesWithSeries(this.searchTerm, this.isRandom).subscribe(book => {
        this.books = book;
      }, error => {
        this.books = [];
      });
    } else {
      this.service.getBooks().subscribe(books => this.books = books);
    }
  }
  
  openVideo(book: Book) {

    const queryParams: PlayerParameters = {
      seriesId : book.seriesId,
      position : book.currentPosition,
      videoId : book.id,
      videosCount : this.episodeCount,
      isRandom : this.isRandom
    };

    const navigationExtras: NavigationExtras = {
      queryParams
   };

   this.router.navigate(['/player'], navigationExtras);
  }
}

export class PlayerParameters {
  videoId: number;
  seriesId: number;
  videosCount: number;
  position: number;
  isRandom: boolean;
}
