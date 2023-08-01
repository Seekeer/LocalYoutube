import { Location } from '@angular/common';
import {
  HttpEvent,
  HttpHandler,
  HttpInterceptor,
  HttpRequest,
} from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Router } from '@angular/router';

import {
  EMPTY,
  Observable,
} from 'rxjs';
import { catchError } from 'rxjs/operators';

import { AuthService } from '../_services/auth.service';

@Injectable()
export class UnauthorizedInterceptor implements HttpInterceptor {
  constructor(private authService: AuthService, private router: Router, public location: Location) {}

  intercept(
    request: HttpRequest<unknown>,
    next: HttpHandler
  ): Observable<HttpEvent<unknown>> {
    return next.handle(request).pipe(
      catchError((err) => {
        if (err.status === 401) {
          this.authService.clearLocalStorage();
          let currentUrl = this.location.path();
          this.router.navigate(['login'], {
            queryParams: { returnUrl: currentUrl },
          });

        return EMPTY;
      }

        return next.handle(request);
      })
    );
  }
}
