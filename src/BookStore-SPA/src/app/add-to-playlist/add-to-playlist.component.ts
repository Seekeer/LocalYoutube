import {
  Component,
  Input,
  OnInit,
} from '@angular/core';

import { Serie } from '../_models/Category';
import { SeriesService } from '../_services/series.service';

@Component({
  selector: 'app-add-to-playlist',
  templateUrl: './add-to-playlist.component.html',
  styleUrls: ['./add-to-playlist.component.css']
})
export class AddToPlaylistComponent implements OnInit {

  playlists: Serie[];
  playlistId: number;
  @Input() videoId: number
  constructor(
    public seriesService: SeriesService,
  ) { }

  ngOnInit(): void {
    this.getPlaylists();
  }

  addToPlaylist(){
    this.seriesService.addToPlaylist(this.playlistId, this.videoId).subscribe();
  }

  getPlaylists() {    
      this.seriesService.getPlaylists().subscribe(playlist => {
      this.playlists = playlist.sort((a, b) => {
        return a.name >= b.name
          ? 1
          : -1
      });
    });
  }
}
