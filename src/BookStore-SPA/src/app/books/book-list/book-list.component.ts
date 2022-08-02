import { HttpClient } from '@angular/common/http';
import {
  Component,
  ElementRef,
  OnInit,
  ViewChild,
  ViewEncapsulation,
} from '@angular/core';
import {
  ActivatedRoute,
  NavigationExtras,
  Router,
} from '@angular/router';

import { NgxSpinnerService } from 'ngx-spinner';
import { ToastrService } from 'ngx-toastr';
import { Subject } from 'rxjs';
import { debounceTime } from 'rxjs/operators';
import {
  Book,
  Book as VideoFile,
  VideoType,
} from 'src/app/_models/Book';
import { Serie } from 'src/app/_models/Category';
import { Seasons } from 'src/app/_models/Seasons';
import {
  ConfirmationDialogService,
} from 'src/app/_services/confirmation-dialog.service';
import { FileService } from 'src/app/_services/file.service';
import { SeriesService } from 'src/app/_services/series.service';

import { NgbModal } from '@ng-bootstrap/ng-bootstrap';

@Component({
  selector: 'app-book-list',
  templateUrl: './book-list.component.html',
  styleUrls: ['./book-list.component.css'],
  styles: [`
    .dark-modal .modal-content {
      background-color: #292b2c;
      color: white;
    }
    .dark-modal .close {
      color: white;
    }
    .light-blue-backdrop {
      background-color: #5cb3fd;
    }
  `],
  encapsulation: ViewEncapsulation.None, //<--this line
})
export class BookListComponent implements OnInit {
  @ViewChild('videoElement') video:ElementRef; 
  
  public books: VideoFile[];
  public listComplet: any;
  public isRandom: boolean = true;
  public isSelectSeries: boolean = false;
  public showKPINfo: boolean = false;
  public serieId: number = 0;
  public seasonId: number = 0;
  public searchTitle: string = '';
  public episodeCount: number = 1;
  public searchValueChanged: Subject<string> = new Subject<string>();
  public series: Serie[];
  public selectedType: VideoType;
  public seasons: Seasons[];
  type: string;

  constructor(private router: Router,
              private service: FileService,
              private seriesService: SeriesService,
              private toastr: ToastrService,
              private http:HttpClient,
              private modalService: NgbModal,
              private spinner: NgxSpinnerService,
              private activatedRoute: ActivatedRoute,
              private confirmationDialogService: ConfirmationDialogService) 
  { 
    this.activatedRoute.queryParams.subscribe(params => {
      console.log(params['type']);
      // let value = params['type'];
      // var color : VideoType = value as unknown as VideoType; 
      }); 

  }

  ngOnInit() {
    this.spinner.show();

    this.type = (this.activatedRoute.snapshot.paramMap.get('type'));

    this.displayListForType();

    this.searchValueChanged.pipe(debounceTime(1000))
    .subscribe(() => {
      this.search();
    });
  }

  displayByType() {
  }
  getSeries(type:VideoType) {
    this.spinner.show();
    
    this.seriesService.getAll(type).subscribe(series => {
      this.spinner.hide();
      this.series = series;
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

  public copyLink(file: Book) {
    this.copyToClipboard(this.service.getVideoURLById(file.id));
  }
  
  private copyToClipboard(text) {
    if(navigator.clipboard) {
      navigator.clipboard.writeText(text);
    }
    else{
      alert(text);
    }
  }

  private search() {

    if(this.searchTitle !== ''){
      this.spinner.show();

      this.service.searchFilesWithTitle(this.searchTitle).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
    }
    else if (this.seasonId != 0) {
      this.service.searchFilesWithSeason(this.seasonId, this.isRandom).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
    }
    else if (this.serieId != 0) {
      let serie = this.series.filter(x => x.id == this.serieId)[0];
      this.seasons = serie.seasons;
      this.spinner.show();
      this.service.searchFilesWithSeries(serie.name, this.isRandom).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
    } 
    else {
            this.toastr.error('Выберите название файла или сериала');
    }
  }

  public udateDownloaded(){
    this.service.updateDownloaded().subscribe(x => this.displayListForType(), this.getFilmsError.bind(this));
  }

displayListForType() {
    switch (this.type){
      case 'series':{
        this.isSelectSeries = true;
        this.getSeries(VideoType.ChildEpisode);
        break;
      }
      case 'soviet':{
        this.isSelectSeries = true;
        this.series = [];
        this.series.push( {id : 9, name : 'Известные', seasons: []});
        this.series.push( {id : 1, name : 'Разные', seasons: []});

        this.service.getSovietAnimation().subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case 'other':{
        this.service.getFilmsByType(VideoType.Unknown).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case 'sovietfairytale':{
        this.service.getFilmsByType(VideoType.FairyTale).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case 'animation':{
        this.service.getBigAnimation().subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case 'balley':{
        this.service.getFilmsByType(VideoType.Balley).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case 'film':{
        this.isSelectSeries = true;
        this.getSeries(VideoType.Film);

        this.service.getFilmsByType(VideoType.Film).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
        this.showKPINfo = true;
        break;
      }
    }
}
  public deleteFilm(content,film: Book){
    let that = this;
    if (window.confirm("Фильм будет удален из базы и с диска?")) {
        this.service.deleteBook(film.id).subscribe(x => that.displayListForType());
    }

    // this.modalService.open(content, { centered: true });
    // this.toastr.warning('Выберите название файла или сериала');
}

  showBooks(books: Book[]) {
    if(this.type != 'film')
      this.books = books.reverse();
    else  
      this.books = books.sort((a,b) => {
      if(a.year > b.year) 
        return -1 ;
      else if(a.year == b.year) 
        return 0 ;
      else
        return 1;
    });
    this.spinner.hide();
  }
  getFilmsError(error) {
    this.spinner.hide();
    this.books = [];
  }

  continueWatch(){
    var film = this.books.find(x => !x.isFinished);

    this.openVideo(film);
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


