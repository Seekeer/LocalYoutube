import {
  Component,
  ElementRef,
  HostListener,
  Input,
  OnChanges,
  OnInit,
  SimpleChanges,
  ViewChild,
} from '@angular/core';

import { Mark } from '../_models/Mark';
import { FileService } from '../_services/file.service';
import { DescriptionRow } from '../books/player/player.component';

@Component({
  selector: 'app-markslist',
  templateUrl: './markslist.component.html',
  styleUrls: ['./markslist.component.css']
})
export class MarkslistComponent implements OnInit, OnChanges {
  @ViewChild('audioElement') audio:ElementRef;
  public marks: Mark[] = [];
  @Input() videoId: number;
  @Input() isHeightLimited: boolean = true;
  @Input() showAddButton: boolean = true;
  lastVolumeChangedTime: Date;
  private _subscribed: any;

  constructor(
    public service: FileService,
  ) { }

  ngOnInit(): void {
    this.newMediaLoaded(this.videoId);
  }

  @HostListener('window:keydown.control.m', ['$event'])
  bigFont(event: KeyboardEvent) {
    event.preventDefault();

    this.addMark();
  }


  public addMark() {
    var element = this.getVideoElement();

    const timeDifference = 5;
    let position = element.currentTime - timeDifference;
    if(position < 0)
      position = 0;

    var mark = new Mark();
    mark.dbFileId = this.videoId;
    mark.position = position;
    mark.isInEditMode = true;

    if(this.marks.find(x => Math.abs((x.position - mark.position)) < 5))
      return;

    this.createMark(mark);
    this.marks.push(mark);
  }

  private createMark(mark: Mark) {
    this.service.addMarkByFile(mark).subscribe((id) => {
      mark.id = id;
    });
  }

  ngOnChanges(changes: SimpleChanges) {
    if(changes['videoId'] != null){
      this.newMediaLoaded(this.videoId);
    }
  }

  public paused() {
    if (this.getVideoElement()?.seeking) return;

    this.lastVolumeChangedTime = new Date();
  }

  public played() {
    this.calculateTimeDiff(
      this.lastVolumeChangedTime,
      () => this.addMark(),
      () => {}
    );
  }


  private calculateTimeDiff(
    date: Date,
    callbackOnLess: Function,
    callbackOnMore: Function
  ) {
    var timeDiff = this.calculateTime(date);
    if (timeDiff > 10 && timeDiff < 2000) {
      callbackOnLess();
    } else {
      callbackOnMore();
    }
  }

  private calculateTime(date: Date) {
    if(!date)
      return 0;
    else
      return new Date().getTime() - date.getTime();
  }

  getVideoElement() {
    // if (!this.mediaElement)
    {
      let audio = document.querySelector(
        '#player'
      );
      var mediaEl = audio as HTMLMediaElement;

      if(!this._subscribed && mediaEl){
        mediaEl.onpause = (event: Event) => this.paused();
        mediaEl.onplay = (event: Event) => this.played();
        this._subscribed = true;
      }

      return mediaEl;
    }
  }

  public rowClicked(row: DescriptionRow) {
    var element = this.getVideoElement();
    element.currentTime = row.getPosition();
  }

  public markClicked(mark: Mark) {
    if(mark.isDeleted)
      return;
    var element = this.getVideoElement();
    element.currentTime = mark.position;
  }

  public deleteMark(mark: Mark) {
    this.service.deleteMark(mark.id).subscribe();
    mark.isDeleted = true;
    mark.isInEditMode = false;

    // this.marks = this.marks.filter((obj) => {
    //   return obj.id !== mark.id;
    // });
  }

  public restoreMark(mark: Mark) {
    mark.id = 0;
    mark.isDeleted = false;
    this.createMark(mark);
  }

  public rewindMark(mark: Mark) {

    mark.position -= 10;
    this.service.updateMark(mark).subscribe();

  }

  public forwardMark(mark: Mark) {
    mark.position += 10;

    this.service.updateMark(mark).subscribe();
  }

  public edit(mark: Mark) {
    mark.isInEditMode = true;
  }

  public stopEdit(mark: Mark, applyEdit: boolean) {
    mark.isInEditMode = false;

    if(applyEdit)
      this.service.updateMark(mark).subscribe();
  }

  public newMediaLoaded(fileId: number){

    if(!fileId)
      return;

    this.videoId = fileId;

    this.service.getMarksByFile(this.videoId).subscribe((marks) => {
      this.getVideoElement();
      this.marks = marks.sort((a,b) =>  a.position - b.position);
    });
  }

  public click(){

    console.log(this.videoId);
    this.newMediaLoaded(this.videoId);
    // let audio = document.querySelector(
    //   'audio'
    // );
    // console.log(audio);
  }
}
