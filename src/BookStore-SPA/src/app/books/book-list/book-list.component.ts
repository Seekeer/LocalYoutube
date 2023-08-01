import { HttpClient } from '@angular/common/http';
import {
  Component,
  ElementRef,
  OnInit,
  ViewChild,
  ViewEncapsulation,
} from '@angular/core';
import { DomSanitizer } from '@angular/platform-browser';
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
  public isRandom: boolean = false;
  public videoType: VideoType;
  public showWatched: boolean = true;
  public showSelected: boolean = false;
  
  public showOnlyWebSupported: boolean;
  
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
  public selected: Book[] =[];
  public selectedGenres:string[];
  public genres: string[] = ['комедия', 'драма', 'боевик', 'детектив', 'фантастика', 'биография', 'фэнтези', 'приключения','мелодрама'];
  type: string;
  apibooks: Book[];
  _numberOfTry = 0;
  public isAndroid: boolean;

  constructor(private router: Router,
              private service: FileService,
              private seriesService: SeriesService,
              private sanitizer: DomSanitizer,
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
    setTimeout(() => this.showSpinner(), 5);

    this.type = (this.activatedRoute.snapshot.paramMap.get('type'));

    this.displayListForType();

    this.searchValueChanged.pipe(debounceTime(1000))
      .subscribe(() => {
        this.search();
      });

    this.detectOs();
  }

  detectOs() {
    let os = this.getOS();
    if(os == "Android")
      this.isAndroid = true;
  }
   getOS() {
    var uA = navigator.userAgent || navigator.vendor ;
    if ((/iPad|iPhone|iPod/.test(uA) && !(<any>window).MSStream) || (uA.includes('Mac') && 'ontouchend' in document)) return 'iOS';
  
    var i, os = ['Windows', 'Android', 'Unix', 'Mac', 'Linux', 'BlackBerry'];
    for (i = 0; i < os.length; i++) if (new RegExp(os[i],'i').test(uA)) return os[i];
  }
  
  getSeries(type:VideoType) {
    this.seriesService.getAll(type).subscribe(series => {
      this.series = series.sort((a, b) => {  
        return a.name >= b.name
          ? 1
          : -1
      });
      this.hideSpinner(); 
    });
  }

  public addBook() {
    this.router.navigate(['/book']);
  }

  public editBook(bookId: number) {
    this.router.navigate(['/book/' + bookId]);
  }

  public filmWatched(film: Book) {

      // this.service.filmWatched(film.id).subscribe(
      //   () => {},
      //   err => {
      //     this.toastr.error('Ошибка.');
      //   });
      this.service.setPosition(film.id, 100000);
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

      this.showSpinner();
    if(this.searchTitle !== ''){

      this.service.searchFilesWithTitle(this.searchTitle).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
    }
    else if (this.seasonId != 0) {
      this.service.searchFilesWithSeason(this.seasonId, this.isRandom).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
    }
    else if (this.serieId != 0) {
      let serie = this.series.filter(x => x.id == this.serieId)[0];
      this.seasons = serie.seasons;
      this.service.searchFilesWithSeries(serie.name, this.isRandom).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
    } 
    else {
            this.toastr.error('Выберите название файла или сериала');
    }
  }

displayListForType() {
    let that = this;
    switch (this.type){
      case 'series':{
        this.isSelectSeries = true;
        this.getSeries(VideoType.ChildEpisode);
        break;
      }
      case 'adultSeries':{
        this.isRandom = false;
        this.isSelectSeries = true;
        this.getSeries(VideoType.AdultEpisode);
        break;
      }
      case 'soviet':{
        this.isSelectSeries = true;
        this.series = [];
        this.series.push( {id : 13, name : 'Известные', seasons: []});
        this.series.push( {id : 14, name : 'Разные', seasons: []});
        this.series.push( {id : 16, name : 'Мультсериалы', seasons: []});

        this.service.getSovietAnimation().subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case 'other':{
          this.seriesService.getOther().subscribe(series => {
            this.series = series;
            this.isSelectSeries = true;
            this.hideSpinner(); 
            this.isRandom = false;
            this.episodeCount = 10;
          });
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
        this.videoType = VideoType.Art;
        this.isRandom = false;
        this.episodeCount = 1000;

        this.service.getFilmsByTypeUniqueSeason(VideoType.Art).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case 'film':{
        this.showSpinner();
        this.isSelectSeries = true;
        this.showWatched  = false;
        this.getSeries(VideoType.Film);

        this.service.getFilmsByType(VideoType.Film).subscribe({
         next: (books) => that.showBooks(books),
         error: (e) => this.getFilmsError(e)
        });
        this.showKPINfo = true;
        break;
      }
    }
}
watchedChanged(event){

  this.showFilteredBooks();
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
    this.apibooks = books;
    this.showFilteredBooks();
  }

  showFilteredBooks() {
    let books = this.apibooks;

    if(this.showSelected)
      books = books.filter(x => x.isSelected);

    if(!this.showWatched)
      books = books.filter(x => !x.isFinished);

    if(this.type != 'film')
      this.books = books;
    else  
    {
      if(this.showOnlyWebSupported)
        books = books.filter(x => x.isSupportedWebPlayer);

      this.books = books.sort((a,b) => {
        if(a.year > b.year) 
          return -1 ;
        else if(a.year == b.year) 
          return 0 ;
        else
          return 1;
      });

      if(this.selectedGenres){
        this.books = this.books.filter(book => {
          var haveGenre = false;
          this.selectedGenres.forEach(genre => {
            if(book.genres?.toLowerCase().indexOf(genre.toLowerCase())!= -1){
              haveGenre = true;
              return;
            }
          });
          return haveGenre;
          });
        }
    }

    this.books.forEach(book => { 
      book.PlayURL = (`vlc://${this.service.getVideoURLById(book.id)}`);
      let hours= Math.floor(book.durationMinutes/60)
      if(hours > 0){
        let ending  = hours==1?'':'а';
        book.hours =hours.toString() +" час"+ending;
      }
    });

    this.hideSpinner(); 
  }

  getFilmsError(error) {
    if(this._numberOfTry++< 10)
      this.displayListForType();
    else{
      this.hideSpinner(); 
      this.books = [];
    }
  }

  hideSpinner(){

      setTimeout(() => {
        this.counter--;

        if(this.counter < 0)
        this.counter = 0;


        if(this.counter == 0)
            this.spinner.hide()
      }, 5);

}

counter : number =0 ;

  public showSpinner(){    
    this.counter++;

    this.spinner.show();
  }
  continueWatch(){
    var film = this.books.find(x => !x.isFinished);

    this.openVideo(film);
  }

  openVideo(book: Book) {

    if(!book.isSupportedWebPlayer){
      window.open(`vlc://${this.service.getVideoURLById(book.id)}`, "_blank");
      return;
    }

    const queryParams: PlayerParameters = {
      seriesId : book.seriesId,
      position : book.currentPosition,
      videoId : book.id,
      videosCount : this.episodeCount,
      isRandom : this.isRandom,
      seasonId : 0
    };
    
    if(this.videoType == VideoType.Art)
      queryParams.seasonId = book.seasonId;

    const navigationExtras: NavigationExtras = {
      queryParams
   };

   this.router.navigate(['/player'], navigationExtras);
  }
}

export class PlayerParameters {
  videoId: number;
  seriesId: number;
  seasonId: number;
  videosCount: number;
  position: number;
  isRandom: boolean;
}


