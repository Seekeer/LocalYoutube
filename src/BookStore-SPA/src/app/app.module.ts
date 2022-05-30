import { HttpClientModule } from '@angular/common/http';
import { NgModule } from '@angular/core';
import { FlexLayoutModule } from '@angular/flex-layout';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { MatSliderModule } from '@angular/material/slider';
import { BrowserModule } from '@angular/platform-browser';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';

import { NgxSpinnerModule } from 'ngx-spinner';
import { ToastrModule } from 'ngx-toastr';

import { NgbModule } from '@ng-bootstrap/ng-bootstrap';

import {
  ConfirmationDialogService,
} from './_services/confirmation-dialog.service';
import { FileService } from './_services/file.service';
import { SeriesService } from './_services/series.service';
import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { BookListComponent } from './books/book-list/book-list.component';
import { PlayerComponent } from './books/player/player.component';
import {
  CategoryListComponent,
} from './categories/category-list/category-list.component';
import { CategoryComponent } from './categories/category/category.component';
import {
  ConfirmationDialogComponent,
} from './confirmation-dialog/confirmation-dialog.component';
import { NgbdDatepickerPopup } from './datepicker/datepicker-popup';
import { HomeComponent } from './home/home.component';
import { NavComponent } from './nav/nav.component';

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
    NgxSpinnerModule,
    MatSliderModule,
    MatFormFieldModule,
    MatButtonModule,
    MatIconModule,
    MatCardModule,
    MatCheckboxModule,
    MatSlideToggleModule,
    MatSelectModule,
    MatInputModule,
    BrowserAnimationsModule,
    FlexLayoutModule,
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
