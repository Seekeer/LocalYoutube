import {
  HttpEvent,
  HttpHandler,
  HttpInterceptor,
  HttpRequest,
} from '@angular/common/http';
import { Injectable } from '@angular/core';

import {
  Observable,
  of,
  throwError,
} from 'rxjs';
import {
  concatMap,
  delay,
  retryWhen,
} from 'rxjs/operators';

export const retryCount = 300;
export const retryWaitMilliSeconds = 10 * 1000;

@Injectable()
export class FailedConnectionInterceptor implements HttpInterceptor {
  constructor() {}

  intercept(request: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    return next.handle(request).pipe(
      retryWhen(error => 
        error.pipe(
          concatMap((error, count) => {
            // if (count <= retryCount && (error.status == 0 ||error.status == 502 || error.status == 503 || error.status == 504)) 
            if ((error.url.includes('marks/add') || error.url.includes('files/updatePosition'))  && count <= retryCount && (error.status == 0 ||error.status == 502 || error.status == 503 || error.status == 504)) 
              return of(error);
            
            return throwError(error);
          }),
          
          delay(retryWaitMilliSeconds)
        )
      )
    )
  }
}