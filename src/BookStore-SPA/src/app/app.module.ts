import {
  HashLocationStrategy,
  LocationStrategy,
} from '@angular/common';
import {
  HTTP_INTERCEPTORS,
  HttpClientModule,
} from '@angular/common/http';
import {
  APP_INITIALIZER,
  NgModule,
} from '@angular/core';
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
import { MatTabsModule } from '@angular/material/tabs';
import { BrowserModule } from '@angular/platform-browser';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';

import { NgxSpinnerModule } from 'ngx-spinner';
import { ToastrModule } from 'ngx-toastr';

import { NgbModule } from '@ng-bootstrap/ng-bootstrap';

import { DurationDisplayPipe } from './_models/SeekPosition';
import { AudioFileService } from './_services/AudioFileService';
import { AuthService } from './_services/auth.service';
import {
  ConfirmationDialogService,
} from './_services/confirmation-dialog.service';
import { FileService } from './_services/file.service';
import { SafePipe } from './_services/SafePipe';
import { SeriesService } from './_services/series.service';
import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { AudioComponent } from './audio/audio.component';
import { appInitializer } from './auth/app-initializer';
import { JwtInterceptor } from './auth/jwt.interceptor';
import { UnauthorizedInterceptor } from './auth/unauthorized.interceptor';
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
import { FailedConnectionInterceptor } from './failedConnection.interceptor';
import { HomeComponent } from './home/home.component';
import { LoginComponent } from './login/login.component';
import { MarkslistComponent } from './markslist/markslist.component';
import { NavComponent } from './nav/nav.component';
import {
  PositionslistComponent,
} from './positionslist/positionslist.component';

@NgModule({
  declarations: [
    AppComponent,
    LoginComponent,
    CategoryComponent,
    CategoryListComponent,
    PlayerComponent,
    BookListComponent,
    HomeComponent,
    NavComponent,
    SafePipe,
    ConfirmationDialogComponent,
    NgbdDatepickerPopup,
    AudioComponent,
    MarkslistComponent,
    PositionslistComponent,
    DurationDisplayPipe
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
    MatTabsModule,
    MatInputModule,
    BrowserAnimationsModule,
    FlexLayoutModule,
    ToastrModule.forRoot()
  ],
  providers: [
    FileService,
    AudioFileService,
    SeriesService,
    ConfirmationDialogService,
    {provide: LocationStrategy, useClass: HashLocationStrategy},
    {
      provide: APP_INITIALIZER,
      useFactory: appInitializer,
      multi: true,
      deps: [AuthService],
    },
    { provide: HTTP_INTERCEPTORS, useClass: JwtInterceptor, multi: true },
    { provide: HTTP_INTERCEPTORS, useClass: FailedConnectionInterceptor, multi: true },
    {
      provide: HTTP_INTERCEPTORS,
      useClass: UnauthorizedInterceptor,
      multi: true,
    },
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }
