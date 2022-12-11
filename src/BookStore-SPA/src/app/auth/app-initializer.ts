import { Observable } from 'rxjs';

import { AuthService } from '../_services/auth.service';

export function appInitializer(
  authService: AuthService
): () => Observable<any> {
  return () => authService.refreshToken();
}
