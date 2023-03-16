import {
  Component,
  OnInit,
} from '@angular/core';
import { ActivatedRoute } from '@angular/router';

import { NgxSpinnerService } from 'ngx-spinner';
import { ToastrService } from 'ngx-toastr';

import {
  AudioFile,
  AudioType,
} from '../_models/Book';
import { Serie } from '../_models/Category';
import { AudioFileService } from '../_services/AudioFileService';
import { SeriesService } from '../_services/series.service';

@Component({
  selector: 'app-audio',
  templateUrl: './audio.component.html',
  styleUrls: ['./audio.component.css'],
})
export class AudioComponent implements OnInit {
  type: string;
  public series: Serie[];
  searchTitle: string;
  seasonId: number;
  seasons: import('c:/Dev/LocalYoutube/src/BookStore-SPA/src/app/_models/Seasons').Seasons[];
  serieId: number;
  apiFiles: AudioFile[];
  filteredFiles: AudioFile[];

  constructor(
    private service: AudioFileService,
    private seriesService: SeriesService,
    private toastr: ToastrService,
    private spinner: NgxSpinnerService,
    private activatedRoute: ActivatedRoute
  ) {}

  ngOnInit(): void {
    setTimeout(() => this.showSpinner(), 5);

    this.type = this.activatedRoute.snapshot.paramMap.get('type');

    this.displayListForType();
  }

  displayListForType() {
    switch (this.type) {
      case 'main': {
        this.getSeries(AudioType.Music);
        break;
      }
    }
  }

  getSeries(type: AudioType) {
    this.seriesService.getAllAudio(type).subscribe((series) => {
      this.series = series.sort((a, b) => {
        return a.name >= b.name ? 1 : -1;
      });
      this.hideSpinner();
    });
  }

  private search() {
    this.showSpinner();

    if (this.searchTitle !== '') {
      this.service
        .searchFilesWithTitle(this.searchTitle)
        .subscribe(this.processFiles.bind(this), this.getFilesError.bind(this));
    } else if (this.seasonId != 0) {
      this.service
        .searchFilesWithSeason(this.seasonId, false)
        .subscribe(this.processFiles.bind(this), this.getFilesError.bind(this));
    } else if (this.serieId != 0) {
      let serie = this.series.filter((x) => x.id == this.serieId)[0];
      this.seasons = serie.seasons;
      this.service
        .searchFilesWithSeries(serie.name, false)
        .subscribe(this.processFiles.bind(this), this.getFilesError.bind(this));
    } else {
      this.toastr.error('Выберите название файла или сериала');
    }
  }

  continueWatch() {
    var film = this.filteredFiles.find((x) => !x.isFinished);

    this.openVideo(film);
  }

  openVideo(film: AudioFile) {
    throw new Error('Method not implemented.');
  }

  processFiles(files: AudioFile[]) {
    this.apiFiles = files;
    this.showFilteredBooks();
  }

  showFilteredBooks() {

    this.apiFiles.forEach(element => {
      element.PlayURL = this.service.getAudioURLById(element.id);
    });

    this.filteredFiles = this.apiFiles;

    this.hideSpinner();
  }

  getFilesError(error) {
    this.hideSpinner();
    this.filteredFiles = [];
  }

  public showSpinner() {
    this.counter++;

    this.spinner.show();
  }

  hideSpinner() {
    setTimeout(() => {
      this.counter--;

      if (this.counter < 0) this.counter = 0;

      if (this.counter == 0) this.spinner.hide();
    }, 5);
  }

  counter: number = 0;
}
