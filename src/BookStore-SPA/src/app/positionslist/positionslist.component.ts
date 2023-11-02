import {
  Component,
  Input,
  OnInit,
} from '@angular/core';

import {
  SeekPosition,
  SeekPositionCollection,
} from '../_models/SeekPosition';

@Component({
  selector: 'app-positionslist',
  templateUrl: './positionslist.component.html',
  styleUrls: ['./positionslist.component.css']
})
export class PositionslistComponent implements OnInit {

  @Input() positions: SeekPositionCollection = new SeekPositionCollection();
  
  constructor() { }

  ngOnInit(): void {
  }

  public clicked(position: SeekPosition) {
    var element = this.getVideoElement();
    element.currentTime = position.originalPosition;
  }

  getVideoElement() {
    let audio = document.querySelector(
      '#player'
    );
    var mediaEl = audio as HTMLMediaElement;
    
    return mediaEl;
  }
}
