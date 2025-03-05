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
  AddToPlaylistComponent = AddToPlaylistComponent;
  static playlists: Serie[];
  static playlistsRequested: boolean;
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
      if(AddToPlaylistComponent.playlistsRequested)
        return;

      AddToPlaylistComponent.playlistsRequested = true;
      this.seriesService.getPlaylists().subscribe(playlist => {
        AddToPlaylistComponent.playlists = playlist.sort((a, b) => {
        return a.name >= b.name
          ? 1
          : -1
      });
    });
  }
}
