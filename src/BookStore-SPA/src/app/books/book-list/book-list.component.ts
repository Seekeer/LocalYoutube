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
  VideoOrigin,
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

export class YearsRange  {
  public start:number;
  public end:number;
}

export enum MenuVideoType {
  childSeries,
  sovietAnimation,
  sovietfairytale,
  animation,
  balley,

  film,
  adultSeries,
  courses,
  audio,
  latest,
  youtube,
  special,
  new,
}

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
  public showOnlineButtons: boolean = false;
  public newSeasonId: string = '14924';
  
  public showOnlyWebSupported: boolean;
  
  public showWatchedCheckbox: boolean = false;
  public isSelectSeries: boolean = false;
  public isSelectSeason: boolean = false;
  public showKPINfo: boolean = false;
  public serieId: number;
  public seasonId: number = 0;
  public searchTitle: string = '';
  public episodeCount: number = 1;
  public searchValueChanged: Subject<string> = new Subject<string>();
  public series: Serie[];
  public selectedType: VideoType;
  public seasons: Seasons[];
  public selected: Book[] =[];
  public selectedGenres:string[];
  public selectedYears:YearsRange[];
  public yearsRange: YearsRange[] = [ {start : 0, end : 1950},
    {start : 1951, end : 1970},
    {start : 1971, end : 1980},
    {start : 1981, end : 1990},
    {start : 1991, end : 2000},
    {start : 2001, end : 2010},
    {start : 2011, end : 2030}].reverse();
  public genres: string[] = ['комедия', 'драма', 'боевик', 'детектив', 'фантастика', 'биография', 'фэнтези', 'приключения','мелодрама'];
  type: MenuVideoType;
  apibooks: Book[];
  _numberOfTry = 0;
  public isAndroid: boolean;
  private readonly defaultEpisodesCount: number = 10;
  allSeasons: Seasons[];
  allSeries: Serie[];

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

    this.type = MenuVideoType[(this.activatedRoute.snapshot.paramMap.get('type'))];

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

  getSeries(type:VideoType|null, origin:VideoOrigin|null = null) {
    this.seriesService.getAll(type, origin).subscribe(series => {
      this.series = series.sort((a, b) => {
        return a.name >= b.name
          ? 1
          : -1
      });

      series.forEach(x => this.sortSeasons(x));
      this.hideSpinner();
      // this.serieId = 6091;
      this.searchBooks();
    });
  }
  sortSeasons(serie: Serie): void {
    serie.seasons = serie.seasons.sort((a, b) => {
      return a.name >= b.name
      ? 1
      : -1});
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
  
  public updateCover(film:Book) {
    this.service.updateCover(film);
  }

  private search() {

      this.showSpinner();
    if(this.searchTitle !== ''){

      this.service.searchFilesWithTitle(this.searchTitle).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
    }
    else if (this.seasonId != 0) {
      this.isRandom = this.isRandom && !this.seasons.filter(x => x.id == this.seasonId)[0].isOrderMatter;

      this.service.searchFilesWithSeason(this.seasonId, this.isRandom).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
    }
    else if (this.serieId ) {
      let serie = this.series.filter(x => x.id == this.serieId)[0];
      this.seasons = serie.seasons;
      this.isRandom = this.isRandom && !serie.isOrderMatter;

      let showAllVideos =  this.type == MenuVideoType.courses ||this.type == MenuVideoType.special || this.type == MenuVideoType.adultSeries ||this.type == MenuVideoType.youtube; 
      this.service.getVideosBySeries(serie.id, showAllVideos ? 1000:this.defaultEpisodesCount, this.isRandom, 0).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
    }
    else {
      this.hideSpinner();
            // this.toastr.error('Выберите название файла или сериала');
    }
  }

displayListForType() {
    let that = this;
    switch (this.type){
      case MenuVideoType.childSeries:{
        this.isRandom = true;

        this.selectSeries(true);

        this.getSeries(VideoType.ChildEpisode);
        break;
      }
      case MenuVideoType.youtube:{
        this.isRandom = false;
        this.isSelectSeason = true;
        this.isSelectSeries = true;
        this.showOnlineButtons = true;
        this.showWatchedCheckbox = true;
        this.showWatched = false;
        this.setSpecialSeries();
        this.getSeries(VideoType.Youtube);
        this.episodeCount = this.defaultEpisodesCount;
        this.service.getFilmsByType(VideoType.Youtube).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;

        break;
      }
      case MenuVideoType.sovietAnimation:{
        this.selectSeries(true);

        this.getSeries(null, VideoOrigin.Soviet);
        this.service.getSovietAnimation().subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case MenuVideoType.courses:{
          this.seriesService.getCourses().subscribe(series => {
            this.showManyEpisodes(series, this.defaultEpisodesCount);
          });
        break;
      }
      case MenuVideoType.adultSeries:{
          this.seriesService.getAdultEpisode().subscribe(series => {
            this.showManyEpisodes(series, this.defaultEpisodesCount);
          });
        break;
      }
      case MenuVideoType.special:{
        this.setSpecialSeries();
        this.showOnlineButtons = true;
        this.showWatchedCheckbox = true;

          this.seriesService.getSpecialAndEot().subscribe(series => {            
            this.showManyEpisodes(series, this.defaultEpisodesCount);
          });
        break;
      }
      case  MenuVideoType.sovietfairytale:{
        this.service.getFilmsByType(VideoType.FairyTale).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case MenuVideoType.animation:{
        this.service.getBigAnimation().subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case MenuVideoType.balley:{
        this.videoType = VideoType.Art;
        this.isRandom = false;
        this.episodeCount = 1000;

        this.service.getFilmsByTypeUniqueSeason(VideoType.Art).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));;
        break;
      }
      case MenuVideoType.film:{
        this.showSpinner();
        this.selectSeries(true);
        this.showWatched  = false;
        this.getSeries(VideoType.Film);

        this.service.getFilmsByType(VideoType.Film).subscribe({
         next: (books) => that.showBooks(books),
         error: (e) => this.getFilmsError(e)
        });
        this.showKPINfo = true;
        break;
      }
      case MenuVideoType.latest:{
        this.showSpinner();
        this.selectSeries(false);
        this.showWatched  = true;

        this.service.getLatest().subscribe({
         next: (books) => {
            that.showBooks(books);
            this.hideSpinner();
         },
         error: (e) => this.getFilmsError(e)
        });
        break;
      }
      case MenuVideoType.new:{
        this.showSpinner();
        this.selectSeries(false);
        this.showWatched  = true;
        this.setSpecialSeries();
        this.showOnlineButtons = true;
        
        this.service.getNew().subscribe({
         next: (books) => {
            that.showBooks(books);
            this.hideSpinner();
         },
         error: (e) => this.getFilmsError(e)
        });
        break;
      }
    }
}

  setSpecialSeries() {
    this.seriesService.getSpecialAndEot().subscribe((series) => {

      this.allSeasons = series.reduce((pr, cur) => [...pr, ...cur.seasons], []).sort((a, b) => {
        return a.name >= b.name ? 1 : -1;
      });
      this.allSeries = series;

      this.hideSpinner();
    });
  }

  showManyEpisodes(series: Serie[],count: number) {
    this.series = series;
    this.selectSeries(true);
    this.hideSpinner();
    this.isRandom = false;
    this.episodeCount = count;
  }

selectSeries(value:boolean){
  this.isSelectSeries = value;
  this.isSelectSeason = value;
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

    if(this.type != MenuVideoType.film)
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
      if(this.selectedYears){
        this.books = this.books.filter(book => {
          var isInRange = false;
          this.selectedYears.forEach(range => {
            if(book.year >= range.start && book.year<= range.end)
            isInRange = true;
              return;
            }
          );
          return isInRange;
          });
        }
    }

    this.books.forEach(book => {
      book.PlayURL = (`vlc://${this.service.getVideoURLById(book.id)}`);
      book.coverURL = (`${this.service.getVideoCoverById(book.id)}`);
      let hours= Math.floor(book.durationMinutes/60)
      if(hours > 0){
        let ending  = hours==1?'':'а';
        book.hours =hours.toString() +" час"+ending;
      }
    });

    this.hideSpinner();
  }

  public filmStarted(book:Book) {
    this.service.filmStarted(book.id).subscribe();
  }

  getFilmsError(error) {
    if(this._numberOfTry++< 1)
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

public changeSeason(film: Book){
  let that = this;
  that.service.moveToSeason(film, film.seasonId).subscribe();//x => that.displayListForType());;
}

public changeSeries(film: Book){
  let that = this;
  that.seriesService.moveSeasonToSeries(film.id, film.seriesId).subscribe();
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

    let showDelete = !isChild(this.type) && this.type != MenuVideoType.adultSeries;
    const queryParams: PlayerParameters = {
      seriesId : book.seriesId,
      videoId : book.id,
      videosCount : this.episodeCount,
      isRandom : this.isRandom,
      seasonId : book.seasonId,
      type: this.type,
      showDeleteButton: showDelete
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
  isRandom: boolean;
  showDeleteButton: boolean;
  type: MenuVideoType;

  static parse(json: string){
    var data = JSON.parse(json);
    const obj: PlayerParameters = {
    videoId:       Number(data.videoId),
    seriesId:      Number(data.seriesId),
    seasonId:      Number(data.seasonId),
      videosCount: Number(data.videosCount),
      isRandom: (data.isRandom === "true"),
      showDeleteButton: (data.showDeleteButton=== "true"),
      type: data.type,
    };
    return obj;
  }
}


function isChild(type: MenuVideoType) {
  return type == MenuVideoType.sovietAnimation || type == MenuVideoType.sovietfairytale || 
  type == MenuVideoType.animation || type == MenuVideoType.childSeries ;
}

