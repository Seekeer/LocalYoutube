import { NgModule } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  RouterModule,
  Routes,
} from '@angular/router';

import { BookListComponent } from './books/book-list/book-list.component';
import { PlayerComponent } from './books/player/player.component';
import {
  CategoryListComponent,
} from './categories/category-list/category-list.component';
import { CategoryComponent } from './categories/category/category.component';
import { HomeComponent } from './home/home.component';

const routes: Routes = [
  { path: 'home', component: HomeComponent },
  // { path: 'books', component: BookListComponent },
  { path: 'books/:type', component: BookListComponent },
  { path: 'player', component: PlayerComponent },
  { path: 'player/:id', component: PlayerComponent },
  { path: 'categories', component: CategoryListComponent },
  { path: 'category', component: CategoryComponent },
  { path: 'category/:id', component: CategoryComponent },
  { path: '**', redirectTo: 'home', pathMatch: 'full' }
];

@NgModule({
  imports: [RouterModule.forRoot(routes),
    FormsModule],
  exports: [RouterModule],
})
export class AppRoutingModule { }
