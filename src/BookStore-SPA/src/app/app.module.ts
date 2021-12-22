import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms';

import { NgbModule } from '@ng-bootstrap/ng-bootstrap';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { ToastrModule } from 'ngx-toastr';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { FileService } from './_services/file.service';
import { ConfirmationDialogService } from './_services/confirmation-dialog.service';
import { CategoryComponent } from './categories/category/category.component';
import { CategoryListComponent } from './categories/category-list/category-list.component';
import { PlayerComponent } from './books/player/player.component';
import { BookListComponent } from './books/book-list/book-list.component';
import { HomeComponent } from './home/home.component';
import { NavComponent } from './nav/nav.component';
import { ConfirmationDialogComponent } from './confirmation-dialog/confirmation-dialog.component';
import { NgbdDatepickerPopup } from './datepicker/datepicker-popup';
import { SeriesService } from './_services/series.service';

@NgModule({
  declarations: [
    AppComponent,
    CategoryComponent,
    CategoryListComponent,
    PlayerComponent,
    BookListComponent,
    HomeComponent,
    NavComponent,
    ConfirmationDialogComponent,
    NgbdDatepickerPopup
  ],
  imports: [
    BrowserModule,
    AppRoutingModule,
    HttpClientModule,
    FormsModule,
    NgbModule,
    BrowserAnimationsModule,
    ToastrModule.forRoot()
  ],
  providers: [
    FileService,
    SeriesService,
    ConfirmationDialogService
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }
