import { NgModule } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  RouterModule,
  Routes,
} from '@angular/router';

import { AuthGuard } from './auth/auth.guard';
import { BookListComponent } from './books/book-list/book-list.component';
import { PlayerComponent } from './books/player/player.component';
import {
  CategoryListComponent,
} from './categories/category-list/category-list.component';
import { CategoryComponent } from './categories/category/category.component';
import { HomeComponent } from './home/home.component';
import { LoginComponent } from './login/login.component';

const routes: Routes = [
  { path: 'home', component: HomeComponent },
  // { path: 'books', component: BookListComponent },
  { path: 'login', component: LoginComponent },
  { path: 'books/:type', component: BookListComponent , canActivate: [AuthGuard]},
  { path: 'player', component: PlayerComponent  , canActivate: [AuthGuard]},
  { path: 'player/:id', component: PlayerComponent  , canActivate: [AuthGuard]},
  { path: 'categories', component: CategoryListComponent , canActivate: [AuthGuard] },
  { path: 'category', component: CategoryComponent  , canActivate: [AuthGuard]},
  { path: 'category/:id', component: CategoryComponent  , canActivate: [AuthGuard]},
  { path: '**', redirectTo: 'home', pathMatch: 'full' }
];

@NgModule({
  imports: [RouterModule.forRoot(routes),
    FormsModule],
  exports: [RouterModule],
})
export class AppRoutingModule { }
