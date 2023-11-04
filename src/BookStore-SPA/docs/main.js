(self["webpackChunkBookStore_SPA"] = self["webpackChunkBookStore_SPA"] || []).push([["main"],{

/***/ 8400:
/*!*********************************!*\
  !*** ./src/app/_models/Book.ts ***!
  \*********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Book": () => (/* binding */ Book),
/* harmony export */   "VideoType": () => (/* binding */ VideoType),
/* harmony export */   "AudioFile": () => (/* binding */ AudioFile),
/* harmony export */   "AudioType": () => (/* binding */ AudioType)
/* harmony export */ });
class Book {
}
var VideoType;
(function (VideoType) {
    VideoType[VideoType["Unknown"] = 0] = "Unknown";
    VideoType[VideoType["Film"] = 1] = "Film";
    VideoType[VideoType["Animation"] = 2] = "Animation";
    VideoType[VideoType["ChildEpisode"] = 3] = "ChildEpisode";
    VideoType[VideoType["FairyTale"] = 4] = "FairyTale";
    VideoType[VideoType["Lessons"] = 5] = "Lessons";
    VideoType[VideoType["Art"] = 6] = "Art";
    VideoType[VideoType["AdultEpisode"] = 7] = "AdultEpisode";
    VideoType[VideoType["Courses"] = 8] = "Courses";
    VideoType[VideoType["Downloaded"] = 9] = "Downloaded";
    VideoType[VideoType["Youtube"] = 10] = "Youtube";
})(VideoType || (VideoType = {}));
class AudioFile extends Book {
}
var AudioType;
(function (AudioType) {
    AudioType[AudioType["Unknown"] = 0] = "Unknown";
    AudioType[AudioType["Music"] = 1] = "Music";
    AudioType[AudioType["Podcast"] = 2] = "Podcast";
    AudioType[AudioType["EoT"] = 3] = "EoT";
    AudioType[AudioType["FairyTale"] = 4] = "FairyTale";
    AudioType[AudioType["Lessons"] = 5] = "Lessons";
})(AudioType || (AudioType = {}));


/***/ }),

/***/ 4552:
/*!*********************************!*\
  !*** ./src/app/_models/Mark.ts ***!
  \*********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "Mark": () => (/* binding */ Mark)
/* harmony export */ });
class Mark {
}


/***/ }),

/***/ 9248:
/*!*****************************************!*\
  !*** ./src/app/_models/SeekPosition.ts ***!
  \*****************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "SeekPosition": () => (/* binding */ SeekPosition),
/* harmony export */   "SeekPositionCollection": () => (/* binding */ SeekPositionCollection),
/* harmony export */   "DurationDisplayPipe": () => (/* binding */ DurationDisplayPipe)
/* harmony export */ });
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @angular/core */ 3184);

class SeekPosition {
}
class SeekPositionCollection {
    constructor() {
        this.seekPositions = [];
    }
    TryAddPosition(originalPosition, newPosition) {
        if (newPosition == originalPosition)
            return;
        if (this.seekPositions.length > 0) {
            const lastPosition = this.seekPositions[this.seekPositions.length - 1];
            if (lastPosition.originalPosition == originalPosition) {
                lastPosition.newPosition = newPosition;
                return;
            }
        }
        if (this.seekPositions.find(x => x.newPosition == newPosition && x.originalPosition == originalPosition))
            return;
        let seekPosition = new SeekPosition();
        seekPosition.originalPosition = originalPosition;
        seekPosition.newPosition = newPosition;
        this.seekPositions.push(seekPosition);
    }
}
class DurationDisplayPipe {
    transform(duration) {
        const oneDay = 24 * 3600 * 1000;
        const localOffset = new Date().getTimezoneOffset() * 60 * 1000;
        let date = new Date(duration * 1000 + localOffset + oneDay);
        console.log(date);
        let dateStr = date.toLocaleTimeString();
        if (dateStr.startsWith('00:'))
            dateStr = dateStr.substring(3);
        return dateStr;
    }
}
DurationDisplayPipe.ɵfac = function DurationDisplayPipe_Factory(t) { return new (t || DurationDisplayPipe)(); };
DurationDisplayPipe.ɵpipe = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵdefinePipe"]({ name: "durationDisplay", type: DurationDisplayPipe, pure: true });


/***/ }),

/***/ 581:
/*!***********************************************!*\
  !*** ./src/app/_services/AudioFileService.ts ***!
  \***********************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AudioFileService": () => (/* binding */ AudioFileService)
/* harmony export */ });
/* harmony import */ var src_environments_environment__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! src/environments/environment */ 4766);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_common_http__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @angular/common/http */ 8784);



class AudioFileService {
    constructor(http) {
        this.http = http;
        this.baseUrl = src_environments_environment__WEBPACK_IMPORTED_MODULE_0__.environment.baseUrl + 'api/';
    }
    getAudioURLById(id) {
        return this.baseUrl + 'AudioFiles/getFileById?fileId=' + id;
    }
    searchFilesWithSeries(searchedValue, isRandom) {
        return this.http.get(`${this.baseUrl}AudioFiles/search-file-with-series/${encodeURIComponent(searchedValue)}/${isRandom}`);
    }
    searchFilesWithSeason(seasonId, isRandom) {
        return this.http.get(`${this.baseUrl}AudioFiles/search-file-with-season/${seasonId}/${isRandom}`);
    }
    searchFilesWithTitle(searchedValue) {
        return this.http.get(`${this.baseUrl}AudioFiles/search/${searchedValue}`);
    }
    setPosition(id, position) {
        var url = this.baseUrl + `AudioFiles/updatePosition/${id}`;
        return this.http.put(url, position).subscribe();
    }
}
AudioFileService.ɵfac = function AudioFileService_Factory(t) { return new (t || AudioFileService)(_angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵinject"](_angular_common_http__WEBPACK_IMPORTED_MODULE_2__.HttpClient)); };
AudioFileService.ɵprov = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdefineInjectable"]({ token: AudioFileService, factory: AudioFileService.ɵfac, providedIn: 'root' });


/***/ }),

/***/ 1947:
/*!***************************************!*\
  !*** ./src/app/_services/SafePipe.ts ***!
  \***************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "SafePipe": () => (/* binding */ SafePipe)
/* harmony export */ });
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_platform_browser__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/platform-browser */ 318);


class SafePipe {
    constructor(sanitizer) {
        this.sanitizer = sanitizer;
    }
    transform(url) {
        return this.sanitizer.bypassSecurityTrustResourceUrl(url);
    }
}
SafePipe.ɵfac = function SafePipe_Factory(t) { return new (t || SafePipe)(_angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵdirectiveInject"](_angular_platform_browser__WEBPACK_IMPORTED_MODULE_1__.DomSanitizer, 16)); };
SafePipe.ɵpipe = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵdefinePipe"]({ name: "safe", type: SafePipe, pure: true });


/***/ }),

/***/ 4167:
/*!*******************************************!*\
  !*** ./src/app/_services/auth.service.ts ***!
  \*******************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AuthService": () => (/* binding */ AuthService)
/* harmony export */ });
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! rxjs */ 4505);
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! rxjs */ 4139);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! rxjs/operators */ 6942);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! rxjs/operators */ 4661);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! rxjs/operators */ 5843);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! rxjs/operators */ 8759);
/* harmony import */ var src_environments_environment__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! src/environments/environment */ 4766);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! @angular/router */ 2816);
/* harmony import */ var _angular_common_http__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! @angular/common/http */ 8784);






class AuthService {
    constructor(router, http) {
        this.router = router;
        this.http = http;
        this.apiUrl = `${src_environments_environment__WEBPACK_IMPORTED_MODULE_0__.environment.baseUrl}api/account`;
        this.timer = null;
        this._user = new rxjs__WEBPACK_IMPORTED_MODULE_1__.BehaviorSubject(null);
        this.user$ = this._user.asObservable();
        window.addEventListener('storage', this.storageEventListener.bind(this));
    }
    storageEventListener(event) {
        if (event.storageArea === localStorage) {
            if (event.key === 'logout-event') {
                this.stopTokenTimer();
                this._user.next(null);
            }
            if (event.key === 'login-event') {
                this.stopTokenTimer();
                this.http.get(`${this.apiUrl}/user`).subscribe((x) => {
                    this._user.next({
                        username: x.username,
                        role: x.role,
                        originalUserName: x.originalUserName,
                    });
                });
            }
        }
    }
    ngOnDestroy() {
        window.removeEventListener('storage', this.storageEventListener.bind(this));
    }
    login(username, password) {
        return this.http
            .post(`${this.apiUrl}/login`, { username, password })
            .pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_2__.map)((x) => {
            this._user.next({
                username: x.username,
                role: x.role,
                originalUserName: x.originalUserName,
            });
            this.setLocalStorage(x);
            this.startTokenTimer();
            return x;
        }));
    }
    logout() {
        this.http
            .post(`${this.apiUrl}/logout`, {})
            .pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_3__.finalize)(() => {
            this.clearLocalStorage();
            this._user.next(null);
            this.stopTokenTimer();
            this.router.navigate(['login']);
        }))
            .subscribe();
    }
    refreshToken() {
        const refreshToken = localStorage.getItem('refresh_token');
        const userName = localStorage.getItem('user_name');
        if (!refreshToken) {
            this.clearLocalStorage();
            return (0,rxjs__WEBPACK_IMPORTED_MODULE_4__.of)(null);
        }
        return this.http
            .post(`${this.apiUrl}/refresh-token`, { refreshToken, userName })
            .pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_2__.map)((x) => {
            this._user.next({
                username: x.username,
                role: x.role,
                originalUserName: x.originalUserName,
            });
            this.setLocalStorage(x);
            this.startTokenTimer();
            return x;
        }));
    }
    setLocalStorage(x) {
        localStorage.setItem('user_name', x.username);
        localStorage.setItem('access_token', x.accessToken);
        localStorage.setItem('refresh_token', x.refreshToken);
        localStorage.setItem('login-event', 'login' + Math.random());
    }
    clearLocalStorage() {
        localStorage.removeItem('user_name');
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        localStorage.setItem('logout-event', 'logout' + Math.random());
    }
    getTokenRemainingTime() {
        const accessToken = localStorage.getItem('access_token');
        if (!accessToken) {
            return 0;
        }
        const jwtToken = JSON.parse(atob(accessToken.split('.')[1]));
        const expires = new Date(jwtToken.exp * 1000);
        return expires.getTime() - Date.now();
    }
    startTokenTimer() {
        const timeout = this.getTokenRemainingTime();
        this.timer = (0,rxjs__WEBPACK_IMPORTED_MODULE_4__.of)(true)
            .pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_5__.delay)(timeout), (0,rxjs_operators__WEBPACK_IMPORTED_MODULE_6__.tap)({
            next: () => this.refreshToken().subscribe(),
        }))
            .subscribe();
    }
    stopTokenTimer() {
        var _a;
        (_a = this.timer) === null || _a === void 0 ? void 0 : _a.unsubscribe();
    }
}
AuthService.ɵfac = function AuthService_Factory(t) { return new (t || AuthService)(_angular_core__WEBPACK_IMPORTED_MODULE_7__["ɵɵinject"](_angular_router__WEBPACK_IMPORTED_MODULE_8__.Router), _angular_core__WEBPACK_IMPORTED_MODULE_7__["ɵɵinject"](_angular_common_http__WEBPACK_IMPORTED_MODULE_9__.HttpClient)); };
AuthService.ɵprov = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_7__["ɵɵdefineInjectable"]({ token: AuthService, factory: AuthService.ɵfac, providedIn: 'root' });


/***/ }),

/***/ 9696:
/*!**********************************************************!*\
  !*** ./src/app/_services/confirmation-dialog.service.ts ***!
  \**********************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "ConfirmationDialogService": () => (/* binding */ ConfirmationDialogService)
/* harmony export */ });
/* harmony import */ var _confirmation_dialog_confirmation_dialog_component__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../confirmation-dialog/confirmation-dialog.component */ 3580);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @ng-bootstrap/ng-bootstrap */ 7544);



class ConfirmationDialogService {
    constructor(modalService) {
        this.modalService = modalService;
    }
    confirm(title, message, btnOkText = 'Ok', btnCancelText = 'Cancel', dialogSize = 'sm') {
        const modalRef = this.modalService.open(_confirmation_dialog_confirmation_dialog_component__WEBPACK_IMPORTED_MODULE_0__.ConfirmationDialogComponent, { size: dialogSize });
        modalRef.componentInstance.title = title;
        modalRef.componentInstance.message = message;
        modalRef.componentInstance.btnOkText = btnOkText;
        modalRef.componentInstance.btnCancelText = btnCancelText;
        return modalRef.result;
    }
}
ConfirmationDialogService.ɵfac = function ConfirmationDialogService_Factory(t) { return new (t || ConfirmationDialogService)(_angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵinject"](_ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_2__.NgbModal)); };
ConfirmationDialogService.ɵprov = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdefineInjectable"]({ token: ConfirmationDialogService, factory: ConfirmationDialogService.ɵfac });


/***/ }),

/***/ 5878:
/*!*******************************************!*\
  !*** ./src/app/_services/file.service.ts ***!
  \*******************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "FileService": () => (/* binding */ FileService)
/* harmony export */ });
/* harmony import */ var src_environments_environment__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! src/environments/environment */ 4766);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_common_http__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @angular/common/http */ 8784);



class FileService {
    constructor(http) {
        this.http = http;
        this.baseUrl = src_environments_environment__WEBPACK_IMPORTED_MODULE_0__.environment.baseUrl + 'api/';
    }
    setSeriesId(serieId, videoId) {
        return this.http.get(`${this.baseUrl}files/moveFileToSerie?fileId=${videoId}&serieId=${serieId}`);
    }
    getMarksByFile(fileId) {
        return this.http.get(`${this.baseUrl}marks/getAllMarks?fileId=${fileId}`);
    }
    deleteMark(fileId) {
        return this.http.delete(this.baseUrl + 'marks/' + fileId);
    }
    addMarkByFile(mark) {
        return this.http.post(this.baseUrl + 'marks/add', mark);
    }
    updateMark(mark) {
        return this.http.post(this.baseUrl + 'marks/update', mark);
    }
    getFilmsByType(type) {
        return this.http.get(`${this.baseUrl}files/getFileByType/${type}`);
    }
    getLatest() {
        return this.http.get(`${this.baseUrl}files/getLatest`);
    }
    filmStarted(fileId) {
        return this.http.patch(`${this.baseUrl}files/filmStarted`, fileId);
    }
    getFilmsByTypeUniqueSeason(type) {
        return this.http.get(`${this.baseUrl}files/getFileByTypeUniqueSeason/${type}`);
    }
    getSovietAnimation() {
        return this.http.get(`${this.baseUrl}files/getAnimation?isSoviet=true`);
    }
    getBigAnimation() {
        return this.http.get(`${this.baseUrl}files/getAnimation?isSoviet=false`);
    }
    getVideoURLById(id) {
        return this.baseUrl + 'Files/getFileById?fileId=' + id;
    }
    getVideoCoverById(id) {
        return this.baseUrl + 'Files/getImage?fileId=' + id;
    }
    getRandomVideoBySeries(seriesId) {
        return this.baseUrl + `Files/getRandomFileBySeriesId?seriesId=${seriesId}&guid=${btoa(Math.random().toString()).substr(10, 15)}`;
    }
    getRandomVideoIdBySeries(seriesId) {
        return this.http.get(this.baseUrl + `Files/getRandomFileIdBySeriesId?seriesId=${seriesId}`);
        // return this.baseUrl +`Files/getRandomFileBySeriesId?seriesId=${seriesId}&guid=${btoa(Math.random().toString()).substr(10, 15)}` ;
    }
    getVideosBySeries(seriesId, count, isRandom, startId) {
        return this.http.get(this.baseUrl + `Files/getFilesBySeries?id=${seriesId}&count=${count}&isRandom=${isRandom}&startId=${startId}`);
    }
    getVideosBySeason(seasonId, count, isRandom, startId) {
        return this.http.get(this.baseUrl + `Files/getFilesBySeason?id=${seasonId}&count=${count}&isRandom=${isRandom}&startId=${startId}`);
    }
    setRating(id, rating) {
        var url = this.baseUrl + `files/rate/${id}`;
        return this.http.put(url, rating);
    }
    setPosition(id, position) {
        var url = this.baseUrl + `files/updatePosition/${id}`;
        return this.http.put(url, position).subscribe();
    }
    getBooks() {
        return this.http.get(this.baseUrl + `files`);
    }
    filmWatched(id) {
        var url = this.baseUrl + `files/filmWatched/${id}`;
        return this.http.put(url, null);
    }
    deleteBook(id) {
        return this.http.delete(this.baseUrl + 'files/' + id);
    }
    getBookById(id) {
        return this.http.get(this.baseUrl + 'files/' + id);
    }
    searchFilesWithSeries(searchedValue, isRandom) {
        return this.http.get(`${this.baseUrl}files/search-file-with-series/${encodeURIComponent(searchedValue)}/${isRandom}`);
    }
    searchFilesWithSeason(seasonId, isRandom) {
        return this.http.get(`${this.baseUrl}files/search-file-with-season/${seasonId}/${isRandom}`);
    }
    searchFilesWithTitle(searchedValue) {
        return this.http.get(`${this.baseUrl}files/search/${searchedValue}`);
    }
}
FileService.ɵfac = function FileService_Factory(t) { return new (t || FileService)(_angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵinject"](_angular_common_http__WEBPACK_IMPORTED_MODULE_2__.HttpClient)); };
FileService.ɵprov = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdefineInjectable"]({ token: FileService, factory: FileService.ɵfac, providedIn: 'root' });


/***/ }),

/***/ 8422:
/*!*********************************************!*\
  !*** ./src/app/_services/series.service.ts ***!
  \*********************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "SeriesService": () => (/* binding */ SeriesService)
/* harmony export */ });
/* harmony import */ var src_environments_environment__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! src/environments/environment */ 4766);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_common_http__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @angular/common/http */ 8784);



class SeriesService {
    constructor(http) {
        this.http = http;
        this.baseUrl = src_environments_environment__WEBPACK_IMPORTED_MODULE_0__.environment.baseUrl + 'api/';
    }
    moveSeasonToFavorite(seasonId) {
        return this.http.get(this.baseUrl + `series/moveSeasonToFavorite?seasonId=` + seasonId);
    }
    getAll(type) {
        return this.http.get(this.baseUrl + `series?type=` + type);
    }
    getAllAudio(type) {
        if (!type)
            return this.http.get(this.baseUrl + `series/getAllAudio`);
        else
            return this.http.get(this.baseUrl + `series/getAllAudio?type=` + type);
        // return this.http.get<Serie[]>(this.baseUrl + `series/getAllAudio`);
    }
    getOther() {
        return this.http.get(this.baseUrl + `series/other`);
    }
    getCategories() {
        return this.http.get(this.baseUrl + `series`);
    }
    addCategory(category) {
        return this.http.post(this.baseUrl + 'Series', category);
    }
    updateCategory(id, category) {
        return this.http.put(this.baseUrl + 'series/' + id, category);
    }
    deleteCategory(id) {
        return this.http.delete(this.baseUrl + 'series/' + id);
    }
    getSerieById(id) {
        return this.http.get(this.baseUrl + 'series/' + id);
    }
    search(name) {
        return this.http.get(`${this.baseUrl}series/search/${name}`);
    }
}
SeriesService.ɵfac = function SeriesService_Factory(t) { return new (t || SeriesService)(_angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵinject"](_angular_common_http__WEBPACK_IMPORTED_MODULE_2__.HttpClient)); };
SeriesService.ɵprov = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdefineInjectable"]({ token: SeriesService, factory: SeriesService.ɵfac, providedIn: 'root' });


/***/ }),

/***/ 809:
/*!***************************************!*\
  !*** ./src/app/app-routing.module.ts ***!
  \***************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AppRoutingModule": () => (/* binding */ AppRoutingModule)
/* harmony export */ });
/* harmony import */ var _angular_forms__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! @angular/forms */ 587);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! @angular/router */ 2816);
/* harmony import */ var _audio_audio_component__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./audio/audio.component */ 3838);
/* harmony import */ var _auth_auth_guard__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./auth/auth.guard */ 2850);
/* harmony import */ var _books_book_list_book_list_component__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./books/book-list/book-list.component */ 2495);
/* harmony import */ var _books_player_player_component__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./books/player/player.component */ 2836);
/* harmony import */ var _categories_category_list_category_list_component__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ./categories/category-list/category-list.component */ 1639);
/* harmony import */ var _categories_category_category_component__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ./categories/category/category.component */ 5793);
/* harmony import */ var _home_home_component__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ./home/home.component */ 7205);
/* harmony import */ var _login_login_component__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! ./login/login.component */ 610);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! @angular/core */ 3184);












const routes = [
    { path: 'home', component: _home_home_component__WEBPACK_IMPORTED_MODULE_6__.HomeComponent },
    // { path: 'books', component: BookListComponent },
    { path: 'login', component: _login_login_component__WEBPACK_IMPORTED_MODULE_7__.LoginComponent },
    { path: 'books/:type', component: _books_book_list_book_list_component__WEBPACK_IMPORTED_MODULE_2__.BookListComponent, canActivate: [_auth_auth_guard__WEBPACK_IMPORTED_MODULE_1__.AuthGuard] },
    { path: 'audio/:type', component: _audio_audio_component__WEBPACK_IMPORTED_MODULE_0__.AudioComponent, canActivate: [_auth_auth_guard__WEBPACK_IMPORTED_MODULE_1__.AuthGuard] },
    { path: 'player', component: _books_player_player_component__WEBPACK_IMPORTED_MODULE_3__.PlayerComponent, canActivate: [_auth_auth_guard__WEBPACK_IMPORTED_MODULE_1__.AuthGuard] },
    { path: 'player/:id', component: _books_player_player_component__WEBPACK_IMPORTED_MODULE_3__.PlayerComponent, canActivate: [_auth_auth_guard__WEBPACK_IMPORTED_MODULE_1__.AuthGuard] },
    { path: 'categories', component: _categories_category_list_category_list_component__WEBPACK_IMPORTED_MODULE_4__.CategoryListComponent, canActivate: [_auth_auth_guard__WEBPACK_IMPORTED_MODULE_1__.AuthGuard] },
    { path: 'category', component: _categories_category_category_component__WEBPACK_IMPORTED_MODULE_5__.CategoryComponent, canActivate: [_auth_auth_guard__WEBPACK_IMPORTED_MODULE_1__.AuthGuard] },
    { path: 'category/:id', component: _categories_category_category_component__WEBPACK_IMPORTED_MODULE_5__.CategoryComponent, canActivate: [_auth_auth_guard__WEBPACK_IMPORTED_MODULE_1__.AuthGuard] },
    { path: '**', redirectTo: 'home', pathMatch: 'full' }
];
class AppRoutingModule {
}
AppRoutingModule.ɵfac = function AppRoutingModule_Factory(t) { return new (t || AppRoutingModule)(); };
AppRoutingModule.ɵmod = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵdefineNgModule"]({ type: AppRoutingModule });
AppRoutingModule.ɵinj = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵdefineInjector"]({ imports: [[_angular_router__WEBPACK_IMPORTED_MODULE_9__.RouterModule.forRoot(routes),
            _angular_forms__WEBPACK_IMPORTED_MODULE_10__.FormsModule], _angular_router__WEBPACK_IMPORTED_MODULE_9__.RouterModule] });
(function () { (typeof ngJitMode === "undefined" || ngJitMode) && _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵsetNgModuleScope"](AppRoutingModule, { imports: [_angular_router__WEBPACK_IMPORTED_MODULE_9__.RouterModule, _angular_forms__WEBPACK_IMPORTED_MODULE_10__.FormsModule], exports: [_angular_router__WEBPACK_IMPORTED_MODULE_9__.RouterModule] }); })();


/***/ }),

/***/ 721:
/*!**********************************!*\
  !*** ./src/app/app.component.ts ***!
  \**********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AppComponent": () => (/* binding */ AppComponent)
/* harmony export */ });
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/router */ 2816);


class AppComponent {
    constructor() {
        this.title = 'BookStore-SPA';
    }
}
AppComponent.ɵfac = function AppComponent_Factory(t) { return new (t || AppComponent)(); };
AppComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵdefineComponent"]({ type: AppComponent, selectors: [["app-root"]], decls: 1, vars: 0, template: function AppComponent_Template(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelement"](0, "router-outlet");
    } }, directives: [_angular_router__WEBPACK_IMPORTED_MODULE_1__.RouterOutlet], styles: ["\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IiIsImZpbGUiOiJhcHAuY29tcG9uZW50LmNzcyJ9 */"] });


/***/ }),

/***/ 23:
/*!*******************************!*\
  !*** ./src/app/app.module.ts ***!
  \*******************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AppModule": () => (/* binding */ AppModule)
/* harmony export */ });
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_26__ = __webpack_require__(/*! @angular/common */ 6362);
/* harmony import */ var _angular_common_http__WEBPACK_IMPORTED_MODULE_27__ = __webpack_require__(/*! @angular/common/http */ 8784);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_25__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_flex_layout__WEBPACK_IMPORTED_MODULE_42__ = __webpack_require__(/*! @angular/flex-layout */ 7114);
/* harmony import */ var _angular_forms__WEBPACK_IMPORTED_MODULE_29__ = __webpack_require__(/*! @angular/forms */ 587);
/* harmony import */ var _angular_material_button__WEBPACK_IMPORTED_MODULE_34__ = __webpack_require__(/*! @angular/material/button */ 7317);
/* harmony import */ var _angular_material_card__WEBPACK_IMPORTED_MODULE_36__ = __webpack_require__(/*! @angular/material/card */ 1961);
/* harmony import */ var _angular_material_checkbox__WEBPACK_IMPORTED_MODULE_37__ = __webpack_require__(/*! @angular/material/checkbox */ 1534);
/* harmony import */ var _angular_material_form_field__WEBPACK_IMPORTED_MODULE_33__ = __webpack_require__(/*! @angular/material/form-field */ 4770);
/* harmony import */ var _angular_material_icon__WEBPACK_IMPORTED_MODULE_35__ = __webpack_require__(/*! @angular/material/icon */ 5590);
/* harmony import */ var _angular_material_input__WEBPACK_IMPORTED_MODULE_40__ = __webpack_require__(/*! @angular/material/input */ 3365);
/* harmony import */ var _angular_material_select__WEBPACK_IMPORTED_MODULE_39__ = __webpack_require__(/*! @angular/material/select */ 1434);
/* harmony import */ var _angular_material_slide_toggle__WEBPACK_IMPORTED_MODULE_38__ = __webpack_require__(/*! @angular/material/slide-toggle */ 6623);
/* harmony import */ var _angular_material_slider__WEBPACK_IMPORTED_MODULE_32__ = __webpack_require__(/*! @angular/material/slider */ 1859);
/* harmony import */ var _angular_platform_browser__WEBPACK_IMPORTED_MODULE_28__ = __webpack_require__(/*! @angular/platform-browser */ 318);
/* harmony import */ var _angular_platform_browser_animations__WEBPACK_IMPORTED_MODULE_41__ = __webpack_require__(/*! @angular/platform-browser/animations */ 3598);
/* harmony import */ var ngx_spinner__WEBPACK_IMPORTED_MODULE_31__ = __webpack_require__(/*! ngx-spinner */ 3947);
/* harmony import */ var ngx_toastr__WEBPACK_IMPORTED_MODULE_43__ = __webpack_require__(/*! ngx-toastr */ 2808);
/* harmony import */ var _ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_30__ = __webpack_require__(/*! @ng-bootstrap/ng-bootstrap */ 7544);
/* harmony import */ var _models_SeekPosition__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./_models/SeekPosition */ 9248);
/* harmony import */ var _services_AudioFileService__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./_services/AudioFileService */ 581);
/* harmony import */ var _services_auth_service__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./_services/auth.service */ 4167);
/* harmony import */ var _services_confirmation_dialog_service__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./_services/confirmation-dialog.service */ 9696);
/* harmony import */ var _services_file_service__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ./_services/file.service */ 5878);
/* harmony import */ var _services_SafePipe__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ./_services/SafePipe */ 1947);
/* harmony import */ var _services_series_service__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ./_services/series.service */ 8422);
/* harmony import */ var _app_routing_module__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! ./app-routing.module */ 809);
/* harmony import */ var _app_component__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! ./app.component */ 721);
/* harmony import */ var _audio_audio_component__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! ./audio/audio.component */ 3838);
/* harmony import */ var _auth_app_initializer__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! ./auth/app-initializer */ 6711);
/* harmony import */ var _auth_jwt_interceptor__WEBPACK_IMPORTED_MODULE_11__ = __webpack_require__(/*! ./auth/jwt.interceptor */ 8635);
/* harmony import */ var _auth_unauthorized_interceptor__WEBPACK_IMPORTED_MODULE_12__ = __webpack_require__(/*! ./auth/unauthorized.interceptor */ 3509);
/* harmony import */ var _books_book_list_book_list_component__WEBPACK_IMPORTED_MODULE_13__ = __webpack_require__(/*! ./books/book-list/book-list.component */ 2495);
/* harmony import */ var _books_player_player_component__WEBPACK_IMPORTED_MODULE_14__ = __webpack_require__(/*! ./books/player/player.component */ 2836);
/* harmony import */ var _categories_category_list_category_list_component__WEBPACK_IMPORTED_MODULE_15__ = __webpack_require__(/*! ./categories/category-list/category-list.component */ 1639);
/* harmony import */ var _categories_category_category_component__WEBPACK_IMPORTED_MODULE_16__ = __webpack_require__(/*! ./categories/category/category.component */ 5793);
/* harmony import */ var _confirmation_dialog_confirmation_dialog_component__WEBPACK_IMPORTED_MODULE_17__ = __webpack_require__(/*! ./confirmation-dialog/confirmation-dialog.component */ 3580);
/* harmony import */ var _datepicker_datepicker_popup__WEBPACK_IMPORTED_MODULE_18__ = __webpack_require__(/*! ./datepicker/datepicker-popup */ 7297);
/* harmony import */ var _failedConnection_interceptor__WEBPACK_IMPORTED_MODULE_19__ = __webpack_require__(/*! ./failedConnection.interceptor */ 2258);
/* harmony import */ var _home_home_component__WEBPACK_IMPORTED_MODULE_20__ = __webpack_require__(/*! ./home/home.component */ 7205);
/* harmony import */ var _login_login_component__WEBPACK_IMPORTED_MODULE_21__ = __webpack_require__(/*! ./login/login.component */ 610);
/* harmony import */ var _markslist_markslist_component__WEBPACK_IMPORTED_MODULE_22__ = __webpack_require__(/*! ./markslist/markslist.component */ 7823);
/* harmony import */ var _nav_nav_component__WEBPACK_IMPORTED_MODULE_23__ = __webpack_require__(/*! ./nav/nav.component */ 3789);
/* harmony import */ var _positionslist_positionslist_component__WEBPACK_IMPORTED_MODULE_24__ = __webpack_require__(/*! ./positionslist/positionslist.component */ 9140);














































class AppModule {
}
AppModule.ɵfac = function AppModule_Factory(t) { return new (t || AppModule)(); };
AppModule.ɵmod = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_25__["ɵɵdefineNgModule"]({ type: AppModule, bootstrap: [_app_component__WEBPACK_IMPORTED_MODULE_8__.AppComponent] });
AppModule.ɵinj = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_25__["ɵɵdefineInjector"]({ providers: [
        _services_file_service__WEBPACK_IMPORTED_MODULE_4__.FileService,
        _services_AudioFileService__WEBPACK_IMPORTED_MODULE_1__.AudioFileService,
        _services_series_service__WEBPACK_IMPORTED_MODULE_6__.SeriesService,
        _services_confirmation_dialog_service__WEBPACK_IMPORTED_MODULE_3__.ConfirmationDialogService,
        { provide: _angular_common__WEBPACK_IMPORTED_MODULE_26__.LocationStrategy, useClass: _angular_common__WEBPACK_IMPORTED_MODULE_26__.HashLocationStrategy },
        {
            provide: _angular_core__WEBPACK_IMPORTED_MODULE_25__.APP_INITIALIZER,
            useFactory: _auth_app_initializer__WEBPACK_IMPORTED_MODULE_10__.appInitializer,
            multi: true,
            deps: [_services_auth_service__WEBPACK_IMPORTED_MODULE_2__.AuthService],
        },
        { provide: _angular_common_http__WEBPACK_IMPORTED_MODULE_27__.HTTP_INTERCEPTORS, useClass: _auth_jwt_interceptor__WEBPACK_IMPORTED_MODULE_11__.JwtInterceptor, multi: true },
        { provide: _angular_common_http__WEBPACK_IMPORTED_MODULE_27__.HTTP_INTERCEPTORS, useClass: _failedConnection_interceptor__WEBPACK_IMPORTED_MODULE_19__.FailedConnectionInterceptor, multi: true },
        {
            provide: _angular_common_http__WEBPACK_IMPORTED_MODULE_27__.HTTP_INTERCEPTORS,
            useClass: _auth_unauthorized_interceptor__WEBPACK_IMPORTED_MODULE_12__.UnauthorizedInterceptor,
            multi: true,
        },
    ], imports: [[
            _angular_platform_browser__WEBPACK_IMPORTED_MODULE_28__.BrowserModule,
            _app_routing_module__WEBPACK_IMPORTED_MODULE_7__.AppRoutingModule,
            _angular_common_http__WEBPACK_IMPORTED_MODULE_27__.HttpClientModule,
            _angular_forms__WEBPACK_IMPORTED_MODULE_29__.FormsModule,
            _ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_30__.NgbModule,
            ngx_spinner__WEBPACK_IMPORTED_MODULE_31__.NgxSpinnerModule,
            _angular_material_slider__WEBPACK_IMPORTED_MODULE_32__.MatSliderModule,
            _angular_material_form_field__WEBPACK_IMPORTED_MODULE_33__.MatFormFieldModule,
            _angular_material_button__WEBPACK_IMPORTED_MODULE_34__.MatButtonModule,
            _angular_material_icon__WEBPACK_IMPORTED_MODULE_35__.MatIconModule,
            _angular_material_card__WEBPACK_IMPORTED_MODULE_36__.MatCardModule,
            _angular_material_checkbox__WEBPACK_IMPORTED_MODULE_37__.MatCheckboxModule,
            _angular_material_slide_toggle__WEBPACK_IMPORTED_MODULE_38__.MatSlideToggleModule,
            _angular_material_select__WEBPACK_IMPORTED_MODULE_39__.MatSelectModule,
            _angular_material_input__WEBPACK_IMPORTED_MODULE_40__.MatInputModule,
            _angular_platform_browser_animations__WEBPACK_IMPORTED_MODULE_41__.BrowserAnimationsModule,
            _angular_flex_layout__WEBPACK_IMPORTED_MODULE_42__.FlexLayoutModule,
            ngx_toastr__WEBPACK_IMPORTED_MODULE_43__.ToastrModule.forRoot()
        ]] });
(function () { (typeof ngJitMode === "undefined" || ngJitMode) && _angular_core__WEBPACK_IMPORTED_MODULE_25__["ɵɵsetNgModuleScope"](AppModule, { declarations: [_app_component__WEBPACK_IMPORTED_MODULE_8__.AppComponent,
        _login_login_component__WEBPACK_IMPORTED_MODULE_21__.LoginComponent,
        _categories_category_category_component__WEBPACK_IMPORTED_MODULE_16__.CategoryComponent,
        _categories_category_list_category_list_component__WEBPACK_IMPORTED_MODULE_15__.CategoryListComponent,
        _books_player_player_component__WEBPACK_IMPORTED_MODULE_14__.PlayerComponent,
        _books_book_list_book_list_component__WEBPACK_IMPORTED_MODULE_13__.BookListComponent,
        _home_home_component__WEBPACK_IMPORTED_MODULE_20__.HomeComponent,
        _nav_nav_component__WEBPACK_IMPORTED_MODULE_23__.NavComponent,
        _services_SafePipe__WEBPACK_IMPORTED_MODULE_5__.SafePipe,
        _confirmation_dialog_confirmation_dialog_component__WEBPACK_IMPORTED_MODULE_17__.ConfirmationDialogComponent,
        _datepicker_datepicker_popup__WEBPACK_IMPORTED_MODULE_18__.NgbdDatepickerPopup,
        _audio_audio_component__WEBPACK_IMPORTED_MODULE_9__.AudioComponent,
        _markslist_markslist_component__WEBPACK_IMPORTED_MODULE_22__.MarkslistComponent,
        _positionslist_positionslist_component__WEBPACK_IMPORTED_MODULE_24__.PositionslistComponent,
        _models_SeekPosition__WEBPACK_IMPORTED_MODULE_0__.DurationDisplayPipe], imports: [_angular_platform_browser__WEBPACK_IMPORTED_MODULE_28__.BrowserModule,
        _app_routing_module__WEBPACK_IMPORTED_MODULE_7__.AppRoutingModule,
        _angular_common_http__WEBPACK_IMPORTED_MODULE_27__.HttpClientModule,
        _angular_forms__WEBPACK_IMPORTED_MODULE_29__.FormsModule,
        _ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_30__.NgbModule,
        ngx_spinner__WEBPACK_IMPORTED_MODULE_31__.NgxSpinnerModule,
        _angular_material_slider__WEBPACK_IMPORTED_MODULE_32__.MatSliderModule,
        _angular_material_form_field__WEBPACK_IMPORTED_MODULE_33__.MatFormFieldModule,
        _angular_material_button__WEBPACK_IMPORTED_MODULE_34__.MatButtonModule,
        _angular_material_icon__WEBPACK_IMPORTED_MODULE_35__.MatIconModule,
        _angular_material_card__WEBPACK_IMPORTED_MODULE_36__.MatCardModule,
        _angular_material_checkbox__WEBPACK_IMPORTED_MODULE_37__.MatCheckboxModule,
        _angular_material_slide_toggle__WEBPACK_IMPORTED_MODULE_38__.MatSlideToggleModule,
        _angular_material_select__WEBPACK_IMPORTED_MODULE_39__.MatSelectModule,
        _angular_material_input__WEBPACK_IMPORTED_MODULE_40__.MatInputModule,
        _angular_platform_browser_animations__WEBPACK_IMPORTED_MODULE_41__.BrowserAnimationsModule,
        _angular_flex_layout__WEBPACK_IMPORTED_MODULE_42__.FlexLayoutModule, ngx_toastr__WEBPACK_IMPORTED_MODULE_43__.ToastrModule] }); })();


/***/ }),

/***/ 3838:
/*!******************************************!*\
  !*** ./src/app/audio/audio.component.ts ***!
  \******************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AudioComponent": () => (/* binding */ AudioComponent)
/* harmony export */ });
/* harmony import */ var _models_Book__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../_models/Book */ 8400);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _services_AudioFileService__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../_services/AudioFileService */ 581);
/* harmony import */ var _services_series_service__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../_services/series.service */ 8422);
/* harmony import */ var ngx_toastr__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ngx-toastr */ 2808);
/* harmony import */ var ngx_spinner__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ngx-spinner */ 3947);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! @angular/router */ 2816);
/* harmony import */ var _angular_material_form_field__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! @angular/material/form-field */ 4770);
/* harmony import */ var _angular_material_input__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! @angular/material/input */ 3365);
/* harmony import */ var _angular_forms__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! @angular/forms */ 587);
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_11__ = __webpack_require__(/*! @angular/common */ 6362);
/* harmony import */ var _angular_material_select__WEBPACK_IMPORTED_MODULE_12__ = __webpack_require__(/*! @angular/material/select */ 1434);
/* harmony import */ var _angular_material_core__WEBPACK_IMPORTED_MODULE_13__ = __webpack_require__(/*! @angular/material/core */ 8133);
/* harmony import */ var _angular_material_button__WEBPACK_IMPORTED_MODULE_14__ = __webpack_require__(/*! @angular/material/button */ 7317);
/* harmony import */ var _angular_material_icon__WEBPACK_IMPORTED_MODULE_15__ = __webpack_require__(/*! @angular/material/icon */ 5590);
/* harmony import */ var _markslist_markslist_component__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../markslist/markslist.component */ 7823);
/* harmony import */ var _angular_flex_layout_extended__WEBPACK_IMPORTED_MODULE_16__ = __webpack_require__(/*! @angular/flex-layout/extended */ 3338);

















const _c0 = ["audioElement"];
const _c1 = ["markslist"];
function AudioComponent_mat_form_field_7_mat_option_4_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](0, "mat-option", 17);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
} if (rf & 2) {
    const data_r7 = ctx.$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵpropertyInterpolate"]("value", data_r7.id);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtextInterpolate1"](" ", data_r7.name, " ");
} }
function AudioComponent_mat_form_field_7_Template(rf, ctx) { if (rf & 1) {
    const _r9 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](0, "mat-form-field", 14);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](1, "mat-label");
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](2, "\u0421\u0435\u0440\u0438\u0430\u043B");
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](3, "mat-select", 15);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵlistener"]("ngModelChange", function AudioComponent_mat_form_field_7_Template_mat_select_ngModelChange_3_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵrestoreView"](_r9); const ctx_r8 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵnextContext"](); return ctx_r8.serieId = $event; })("ngModelChange", function AudioComponent_mat_form_field_7_Template_mat_select_ngModelChange_3_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵrestoreView"](_r9); const ctx_r10 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵnextContext"](); return ctx_r10.search(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtemplate"](4, AudioComponent_mat_form_field_7_mat_option_4_Template, 2, 2, "mat-option", 16);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r0 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngModel", ctx_r0.serieId)("disabled", ctx_r0.serieId);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngForOf", ctx_r0.series);
} }
function AudioComponent_mat_form_field_8_mat_option_4_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](0, "mat-option", 17);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
} if (rf & 2) {
    const data_r12 = ctx.$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵpropertyInterpolate"]("value", data_r12.id);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtextInterpolate1"](" ", data_r12.name, " ");
} }
function AudioComponent_mat_form_field_8_Template(rf, ctx) { if (rf & 1) {
    const _r14 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](0, "mat-form-field", 14);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](1, "mat-label");
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](2, "\u0421\u0435\u0437\u043E\u043D");
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](3, "mat-select", 18);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵlistener"]("ngModelChange", function AudioComponent_mat_form_field_8_Template_mat_select_ngModelChange_3_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵrestoreView"](_r14); const ctx_r13 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵnextContext"](); return ctx_r13.seasonId = $event; })("ngModelChange", function AudioComponent_mat_form_field_8_Template_mat_select_ngModelChange_3_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵrestoreView"](_r14); const ctx_r15 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵnextContext"](); return ctx_r15.search(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtemplate"](4, AudioComponent_mat_form_field_8_mat_option_4_Template, 2, 2, "mat-option", 16);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngModel", ctx_r1.seasonId);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngForOf", ctx_r1.seasons);
} }
function AudioComponent_div_9_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](0, "div");
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r2 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtextInterpolate"](ctx_r2.selectedFile.name);
} }
function AudioComponent_app_markslist_23_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelement"](0, "app-markslist", 19, 20);
} if (rf & 2) {
    const ctx_r4 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("videoId", ctx_r4.fileId);
} }
const _c2 = function (a0) { return { "greenBackground": a0 }; };
function AudioComponent_li_27_Template(rf, ctx) { if (rf & 1) {
    const _r19 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](0, "li", 21);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵlistener"]("click", function AudioComponent_li_27_Template_li_click_0_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵrestoreView"](_r19); const file_r17 = restoredCtx.$implicit; const ctx_r18 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵnextContext"](); return ctx_r18.selectAudio(file_r17); });
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](2, "span", 22);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
} if (rf & 2) {
    const file_r17 = ctx.$implicit;
    const ctx_r5 = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngClass", _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵpureFunction1"](3, _c2, file_r17.id == ctx_r5.selectedFile.id));
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtextInterpolate1"](" ", file_r17.name, " ");
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtextInterpolate"](file_r17.durationMinutes);
} }
class AudioComponent {
    constructor(service, seriesService, toastr, spinner, activatedRoute) {
        this.service = service;
        this.seriesService = seriesService;
        this.toastr = toastr;
        this.spinner = spinner;
        this.activatedRoute = activatedRoute;
        this.isSelectSeries = true;
        this.isChild = false;
        this.currentIndex = -1;
        this.forwardSpeed = 0;
        this.rewindSpeed = 0;
        this.counter = 0;
    }
    ngOnInit() {
        setTimeout(() => this.showSpinner(), 5);
        this.type = this.activatedRoute.snapshot.paramMap.get('type');
        this.displayListForType();
        this.intervalId = setInterval(() => this.updateStat(), 1000);
    }
    displayListForType() {
        switch (this.type) {
            case 'child': {
                this.isChild = true;
                this.getSeries(_models_Book__WEBPACK_IMPORTED_MODULE_0__.AudioType.FairyTale);
                break;
            }
            case 'main': {
                this.getSeries(null);
                break;
            }
        }
    }
    getSeries(type) {
        this.seriesService.getAllAudio(type).subscribe((series) => {
            this.series = series.sort((a, b) => {
                return a.name >= b.name ? 1 : -1;
            });
            this.hideSpinner();
        });
    }
    toFavorite() {
        this.seriesService.moveSeasonToFavorite(this.seasonId).subscribe();
    }
    search() {
        this.showSpinner();
        this.currentIndex = -1;
        if (this.searchTitle) {
            this.service
                .searchFilesWithTitle(this.searchTitle)
                .subscribe(this.processFiles.bind(this), this.getFilesError.bind(this));
        }
        else if (this.seasonId) {
            this.service
                .searchFilesWithSeason(this.seasonId, false)
                .subscribe(this.processFiles.bind(this), this.getFilesError.bind(this));
        }
        else if (this.serieId) {
            let serie = this.series.filter((x) => x.id == this.serieId)[0];
            this.seasons = serie.seasons;
            this.service
                .searchFilesWithSeries(serie.name, false)
                .subscribe(() => { this.hideSpinner(); }, this.getFilesError.bind(this));
        }
        else {
            this.toastr.error('Выберите название файла или сериала');
        }
    }
    openVideo(film) {
        throw new Error('Method not implemented.');
    }
    processFiles(files) {
        this.apiFiles = files;
        this.showFilteredBooks();
    }
    selectAudio(file) {
        this.setVideoByIndex(file.index);
    }
    showFilteredBooks() {
        this.apiFiles.forEach((element, index) => {
            element.PlayURL = this.service.getAudioURLById(element.id);
            element.index = index;
        });
        this.filteredFiles = this.apiFiles;
        this.hideSpinner();
        this.selectedFile = new _models_Book__WEBPACK_IMPORTED_MODULE_0__.AudioFile();
        // this.videoEnded();
    }
    getFilesError(error) {
        this.hideSpinner();
        this.filteredFiles = [];
    }
    showSpinner() {
        this.counter++;
        this.spinner.show();
    }
    hideSpinner() {
        setTimeout(() => {
            this.counter--;
            if (this.counter < 0)
                this.counter = 0;
            if (this.counter == 0)
                this.spinner.hide();
        }, 5);
    }
    updateStat() {
        var video = this.getAudioElement();
        if (video.currentTime > 10 && this.selectedFile)
            this.service.setPosition(this.selectedFile.id, video.currentTime);
        // this.setPosition();
    }
    getAudioElement() {
        if (this.audio)
            return this.audio.nativeElement;
    }
    setPosition() {
        var video = this.getAudioElement();
        if (this.position > 0 && video) {
            video.currentTime = this.position;
            this.position = -1;
        }
    }
    forwardVideo() {
        this.updateCurrentTime(10);
    }
    rewindVideo() {
        this.updateCurrentTime(-10);
    }
    updateCurrentTime(delta) {
        let isRewinding = delta < 0;
        if (isRewinding) {
            this.rewindSpeed = this.rewindSpeed + delta;
            this.forwardSpeed = 0;
        }
        else {
            this.forwardSpeed = this.forwardSpeed + delta;
            this.rewindSpeed = 0;
        }
        //clear the timeout
        clearTimeout(this.timer);
        let speed = isRewinding ? this.rewindSpeed : this.forwardSpeed;
        this.getAudioElement().currentTime =
            this.getAudioElement().currentTime + speed;
        //reset accumulator within 2 seconds of a double click
        this.timer = setTimeout(function () {
            this.rewindSpeed = 0;
            this.forwardSpeed = 0;
        }, 2000); // you can edit this delay value for the timeout, i have it set for 2 seconds
    }
    continue() {
        for (let index = 0; index < this.apiFiles.length; index++) {
            const element = this.apiFiles[index];
            if (!element.isFinished && element.index) {
                this.setVideoByIndex(element.index);
                return;
            }
        }
        this.setVideoByIndex(0);
    }
    videoEnded() {
        console.log('ended');
        if (this.setNextVideo())
            this.getAudioElement().load();
    }
    setNextVideo() {
        return this.setVideoByIndex(this.currentIndex + 1);
    }
    setVideoByIndex(index) {
        this.currentIndex = index;
        this.fileId = this.selectedFile.id;
        this.selectedFile = this.filteredFiles[this.currentIndex];
        this.audioURL = this.selectedFile.PlayURL;
        var el = this.getAudioElement();
        el === null || el === void 0 ? void 0 : el.load();
        this.position = this.selectedFile.currentPosition;
        this.setPosition();
        return true;
    }
}
AudioComponent.ɵfac = function AudioComponent_Factory(t) { return new (t || AudioComponent)(_angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵdirectiveInject"](_services_AudioFileService__WEBPACK_IMPORTED_MODULE_1__.AudioFileService), _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵdirectiveInject"](_services_series_service__WEBPACK_IMPORTED_MODULE_2__.SeriesService), _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵdirectiveInject"](ngx_toastr__WEBPACK_IMPORTED_MODULE_5__.ToastrService), _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵdirectiveInject"](ngx_spinner__WEBPACK_IMPORTED_MODULE_6__.NgxSpinnerService), _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵdirectiveInject"](_angular_router__WEBPACK_IMPORTED_MODULE_7__.ActivatedRoute)); };
AudioComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵdefineComponent"]({ type: AudioComponent, selectors: [["app-audio"]], viewQuery: function AudioComponent_Query(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵviewQuery"](_c0, 5);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵviewQuery"](_c1, 5);
    } if (rf & 2) {
        let _t;
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵqueryRefresh"](_t = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵloadQuery"]()) && (ctx.audio = _t.first);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵqueryRefresh"](_t = _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵloadQuery"]()) && (ctx.child = _t.first);
    } }, decls: 28, vars: 7, consts: [[1, "col-md-12"], ["type", "ball-scale-multiple"], ["appearance", "fill", 1, "example-full-width"], ["matInput", "", 3, "ngModel", "ngModelChange"], ["appearance", "fill", 4, "ngIf"], [4, "ngIf"], ["id", "player", "controls", "", "height", "auto", "autoplay", "", 3, "src", "ended"], ["audioElement", ""], [1, "btn", "btn-outline-success", "btn-sm", 3, "click"], ["mat-icon-button", "", "color", "accent", 3, "click"], [1, "btn", "btn-outline-danger", "btn-sm", 3, "click"], [3, "videoId", 4, "ngIf"], [1, "list-group", "list-group-light"], ["class", "list-group-item d-flex justify-content-between align-items-center", 3, "ngClass", "click", 4, "ngFor", "ngForOf"], ["appearance", "fill"], [3, "ngModel", "disabled", "ngModelChange"], [3, "value", 4, "ngFor", "ngForOf"], [3, "value"], [3, "ngModel", "ngModelChange"], [3, "videoId"], ["markslist", ""], [1, "list-group-item", "d-flex", "justify-content-between", "align-items-center", 3, "ngClass", "click"], [1, "badge", "badge-primary", "rounded-pill"]], template: function AudioComponent_Template(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](0, "div", 0);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelement"](1, "ngx-spinner", 1);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](2, "div");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](3, "mat-form-field", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](4, "mat-label");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](5, "\u041D\u0430\u0437\u0432\u0430\u043D\u0438\u0435");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](6, "input", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵlistener"]("ngModelChange", function AudioComponent_Template_input_ngModelChange_6_listener($event) { return ctx.searchTitle = $event; })("ngModelChange", function AudioComponent_Template_input_ngModelChange_6_listener() { return ctx.search(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtemplate"](7, AudioComponent_mat_form_field_7_Template, 5, 3, "mat-form-field", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtemplate"](8, AudioComponent_mat_form_field_8_Template, 5, 2, "mat-form-field", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtemplate"](9, AudioComponent_div_9_Template, 2, 1, "div", 5);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](10, "audio", 6, 7);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵlistener"]("ended", function AudioComponent_Template_audio_ended_10_listener() { return ctx.videoEnded(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](12, "div");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](13, "button", 8);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵlistener"]("click", function AudioComponent_Template_button_click_13_listener() { return ctx.continue(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](14, "\u0412\u043E\u0437\u043E\u0431\u043D\u043E\u0432\u0438\u0442\u044C");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](15, "button", 9);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵlistener"]("click", function AudioComponent_Template_button_click_15_listener() { return ctx.rewindVideo(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](16, "mat-icon");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](17, "fast_rewind");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](18, "button", 9);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵlistener"]("click", function AudioComponent_Template_button_click_18_listener() { return ctx.forwardVideo(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](19, "mat-icon");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](20, "fast_forward");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](21, "button", 10);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵlistener"]("click", function AudioComponent_Template_button_click_21_listener() { return ctx.videoEnded(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](22, "\u0421\u043B\u0435\u0434\u0443\u044E\u0449\u0438\u0439");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtemplate"](23, AudioComponent_app_markslist_23_Template, 2, 1, "app-markslist", 11);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](24, "button", 8);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵlistener"]("click", function AudioComponent_Template_button_click_24_listener() { return ctx.toFavorite(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtext"](25, "\u0412 \u0438\u0437\u0431\u0440\u0430\u043D\u043D\u043E\u0435");
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementStart"](26, "ul", 12);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵtemplate"](27, AudioComponent_li_27_Template, 4, 5, "li", 13);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵelementEnd"]();
    } if (rf & 2) {
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](6);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngModel", ctx.searchTitle);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngIf", ctx.isSelectSeries);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngIf", ctx.isSelectSeries);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngIf", ctx.selectedFile);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵpropertyInterpolate"]("src", ctx.audioURL, _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵsanitizeUrl"]);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](13);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngIf", !ctx.isChild);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵadvance"](4);
        _angular_core__WEBPACK_IMPORTED_MODULE_4__["ɵɵproperty"]("ngForOf", ctx.filteredFiles);
    } }, directives: [ngx_spinner__WEBPACK_IMPORTED_MODULE_6__.NgxSpinnerComponent, _angular_material_form_field__WEBPACK_IMPORTED_MODULE_8__.MatFormField, _angular_material_form_field__WEBPACK_IMPORTED_MODULE_8__.MatLabel, _angular_material_input__WEBPACK_IMPORTED_MODULE_9__.MatInput, _angular_forms__WEBPACK_IMPORTED_MODULE_10__.DefaultValueAccessor, _angular_forms__WEBPACK_IMPORTED_MODULE_10__.NgControlStatus, _angular_forms__WEBPACK_IMPORTED_MODULE_10__.NgModel, _angular_common__WEBPACK_IMPORTED_MODULE_11__.NgIf, _angular_material_select__WEBPACK_IMPORTED_MODULE_12__.MatSelect, _angular_common__WEBPACK_IMPORTED_MODULE_11__.NgForOf, _angular_material_core__WEBPACK_IMPORTED_MODULE_13__.MatOption, _angular_material_button__WEBPACK_IMPORTED_MODULE_14__.MatButton, _angular_material_icon__WEBPACK_IMPORTED_MODULE_15__.MatIcon, _markslist_markslist_component__WEBPACK_IMPORTED_MODULE_3__.MarkslistComponent, _angular_common__WEBPACK_IMPORTED_MODULE_11__.NgClass, _angular_flex_layout_extended__WEBPACK_IMPORTED_MODULE_16__.DefaultClassDirective], styles: ["li[_ngcontent-%COMP%]{cursor: pointer;}\r\n\r\n.greenBackground[_ngcontent-%COMP%]{\r\n    background-color: rgb(136, 190, 136);\r\n}\r\n\r\naudio[_ngcontent-%COMP%]{\r\n    width: 600px;\r\n}\r\n\r\n.btn[_ngcontent-%COMP%]{\r\n    margin-right: 15px;\r\n}\r\n\r\nbutton[mat-icon-button][_ngcontent-%COMP%] {\r\n    transform: scale(1.5);\r\n  }\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbImF1ZGlvLmNvbXBvbmVudC5jc3MiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IkFBQUEsR0FBRyxlQUFlLENBQUM7O0FBRW5CO0lBQ0ksb0NBQW9DO0FBQ3hDOztBQUVBO0lBQ0ksWUFBWTtBQUNoQjs7QUFFQTtJQUNJLGtCQUFrQjtBQUN0Qjs7QUFFQTtJQUNJLHFCQUFxQjtFQUN2QiIsImZpbGUiOiJhdWRpby5jb21wb25lbnQuY3NzIiwic291cmNlc0NvbnRlbnQiOlsibGl7Y3Vyc29yOiBwb2ludGVyO31cclxuXHJcbi5ncmVlbkJhY2tncm91bmR7XHJcbiAgICBiYWNrZ3JvdW5kLWNvbG9yOiByZ2IoMTM2LCAxOTAsIDEzNik7XHJcbn1cclxuXHJcbmF1ZGlve1xyXG4gICAgd2lkdGg6IDYwMHB4O1xyXG59XHJcblxyXG4uYnRue1xyXG4gICAgbWFyZ2luLXJpZ2h0OiAxNXB4O1xyXG59XHJcblxyXG5idXR0b25bbWF0LWljb24tYnV0dG9uXSB7XHJcbiAgICB0cmFuc2Zvcm06IHNjYWxlKDEuNSk7XHJcbiAgfVxyXG4gICJdfQ== */"] });


/***/ }),

/***/ 6711:
/*!*****************************************!*\
  !*** ./src/app/auth/app-initializer.ts ***!
  \*****************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "appInitializer": () => (/* binding */ appInitializer)
/* harmony export */ });
function appInitializer(authService) {
    return () => authService.refreshToken();
}


/***/ }),

/***/ 2850:
/*!************************************!*\
  !*** ./src/app/auth/auth.guard.ts ***!
  \************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "AuthGuard": () => (/* binding */ AuthGuard)
/* harmony export */ });
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! rxjs/operators */ 6942);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! @angular/router */ 2816);
/* harmony import */ var _services_auth_service__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../_services/auth.service */ 4167);




class AuthGuard {
    constructor(router, authService) {
        this.router = router;
        this.authService = authService;
    }
    canActivate(next, state) {
        return this.authService.user$.pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_1__.map)((user) => {
            if (user) {
                return true;
            }
            else {
                this.router.navigate(['login'], {
                    queryParams: { returnUrl: state.url },
                });
                return false;
            }
        }));
    }
}
AuthGuard.ɵfac = function AuthGuard_Factory(t) { return new (t || AuthGuard)(_angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵinject"](_angular_router__WEBPACK_IMPORTED_MODULE_3__.Router), _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵinject"](_services_auth_service__WEBPACK_IMPORTED_MODULE_0__.AuthService)); };
AuthGuard.ɵprov = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵdefineInjectable"]({ token: AuthGuard, factory: AuthGuard.ɵfac, providedIn: 'root' });


/***/ }),

/***/ 8635:
/*!*****************************************!*\
  !*** ./src/app/auth/jwt.interceptor.ts ***!
  \*****************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "JwtInterceptor": () => (/* binding */ JwtInterceptor)
/* harmony export */ });
/* harmony import */ var src_environments_environment__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! src/environments/environment */ 4766);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _services_auth_service__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../_services/auth.service */ 4167);



class JwtInterceptor {
    constructor(authService) {
        this.authService = authService;
    }
    intercept(request, next) {
        // add JWT auth header if a user is logged in for API requests
        const accessToken = localStorage.getItem('access_token');
        const isApiUrl = request.url.startsWith(src_environments_environment__WEBPACK_IMPORTED_MODULE_0__.environment.baseUrl);
        if (accessToken && isApiUrl) {
            request = request.clone({
                setHeaders: { Authorization: `Bearer ${accessToken}` },
            });
        }
        return next.handle(request);
    }
}
JwtInterceptor.ɵfac = function JwtInterceptor_Factory(t) { return new (t || JwtInterceptor)(_angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵinject"](_services_auth_service__WEBPACK_IMPORTED_MODULE_1__.AuthService)); };
JwtInterceptor.ɵprov = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵdefineInjectable"]({ token: JwtInterceptor, factory: JwtInterceptor.ɵfac });


/***/ }),

/***/ 3509:
/*!**************************************************!*\
  !*** ./src/app/auth/unauthorized.interceptor.ts ***!
  \**************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "UnauthorizedInterceptor": () => (/* binding */ UnauthorizedInterceptor)
/* harmony export */ });
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! rxjs */ 6439);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! rxjs/operators */ 7418);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _services_auth_service__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../_services/auth.service */ 4167);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! @angular/router */ 2816);
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! @angular/common */ 6362);






class UnauthorizedInterceptor {
    constructor(authService, router, location) {
        this.authService = authService;
        this.router = router;
        this.location = location;
    }
    intercept(request, next) {
        return next.handle(request).pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_1__.catchError)((err) => {
            if (err.status === 401) {
                this.authService.clearLocalStorage();
                let currentUrl = this.location.path();
                this.router.navigate(['login'], {
                    queryParams: { returnUrl: currentUrl },
                });
                return rxjs__WEBPACK_IMPORTED_MODULE_2__.EMPTY;
            }
            return next.handle(request);
        }));
    }
}
UnauthorizedInterceptor.ɵfac = function UnauthorizedInterceptor_Factory(t) { return new (t || UnauthorizedInterceptor)(_angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵinject"](_services_auth_service__WEBPACK_IMPORTED_MODULE_0__.AuthService), _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵinject"](_angular_router__WEBPACK_IMPORTED_MODULE_4__.Router), _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵinject"](_angular_common__WEBPACK_IMPORTED_MODULE_5__.Location)); };
UnauthorizedInterceptor.ɵprov = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵdefineInjectable"]({ token: UnauthorizedInterceptor, factory: UnauthorizedInterceptor.ɵfac });


/***/ }),

/***/ 2495:
/*!********************************************************!*\
  !*** ./src/app/books/book-list/book-list.component.ts ***!
  \********************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "YearsRange": () => (/* binding */ YearsRange),
/* harmony export */   "BookListComponent": () => (/* binding */ BookListComponent),
/* harmony export */   "PlayerParameters": () => (/* binding */ PlayerParameters)
/* harmony export */ });
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! rxjs */ 2218);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! rxjs/operators */ 823);
/* harmony import */ var src_app_models_Book__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! src/app/_models/Book */ 8400);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! @angular/router */ 2816);
/* harmony import */ var src_app_services_file_service__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! src/app/_services/file.service */ 5878);
/* harmony import */ var src_app_services_series_service__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! src/app/_services/series.service */ 8422);
/* harmony import */ var _angular_platform_browser__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! @angular/platform-browser */ 318);
/* harmony import */ var ngx_toastr__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! ngx-toastr */ 2808);
/* harmony import */ var _angular_common_http__WEBPACK_IMPORTED_MODULE_11__ = __webpack_require__(/*! @angular/common/http */ 8784);
/* harmony import */ var _ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_12__ = __webpack_require__(/*! @ng-bootstrap/ng-bootstrap */ 7544);
/* harmony import */ var ngx_spinner__WEBPACK_IMPORTED_MODULE_13__ = __webpack_require__(/*! ngx-spinner */ 3947);
/* harmony import */ var src_app_services_confirmation_dialog_service__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! src/app/_services/confirmation-dialog.service */ 9696);
/* harmony import */ var _angular_material_form_field__WEBPACK_IMPORTED_MODULE_14__ = __webpack_require__(/*! @angular/material/form-field */ 4770);
/* harmony import */ var _angular_material_input__WEBPACK_IMPORTED_MODULE_15__ = __webpack_require__(/*! @angular/material/input */ 3365);
/* harmony import */ var _angular_forms__WEBPACK_IMPORTED_MODULE_16__ = __webpack_require__(/*! @angular/forms */ 587);
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_17__ = __webpack_require__(/*! @angular/common */ 6362);
/* harmony import */ var _angular_material_select__WEBPACK_IMPORTED_MODULE_18__ = __webpack_require__(/*! @angular/material/select */ 1434);
/* harmony import */ var _angular_material_core__WEBPACK_IMPORTED_MODULE_19__ = __webpack_require__(/*! @angular/material/core */ 8133);
/* harmony import */ var _angular_material_checkbox__WEBPACK_IMPORTED_MODULE_20__ = __webpack_require__(/*! @angular/material/checkbox */ 1534);
/* harmony import */ var _angular_material_button__WEBPACK_IMPORTED_MODULE_21__ = __webpack_require__(/*! @angular/material/button */ 7317);
/* harmony import */ var _angular_material_icon__WEBPACK_IMPORTED_MODULE_22__ = __webpack_require__(/*! @angular/material/icon */ 5590);
/* harmony import */ var _angular_flex_layout_flex__WEBPACK_IMPORTED_MODULE_23__ = __webpack_require__(/*! @angular/flex-layout/flex */ 5434);
/* harmony import */ var _angular_material_card__WEBPACK_IMPORTED_MODULE_24__ = __webpack_require__(/*! @angular/material/card */ 1961);
/* harmony import */ var _angular_flex_layout_extended__WEBPACK_IMPORTED_MODULE_25__ = __webpack_require__(/*! @angular/flex-layout/extended */ 3338);
/* harmony import */ var _services_SafePipe__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ../../_services/SafePipe */ 1947);


























const _c0 = ["videoElement"];
function BookListComponent_mat_form_field_7_mat_option_4_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-option", 15);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const data_r16 = ctx.$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵpropertyInterpolate"]("value", data_r16.id);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate1"](" ", data_r16.name, " ");
} }
function BookListComponent_mat_form_field_7_Template(rf, ctx) { if (rf & 1) {
    const _r18 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-form-field", 12);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](1, "mat-label");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](2, "\u0421\u0435\u0440\u0438\u0430\u043B");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](3, "mat-select", 13);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("ngModelChange", function BookListComponent_mat_form_field_7_Template_mat_select_ngModelChange_3_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r18); const ctx_r17 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r17.serieId = $event; })("ngModelChange", function BookListComponent_mat_form_field_7_Template_mat_select_ngModelChange_3_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r18); const ctx_r19 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r19.searchBooks(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](4, BookListComponent_mat_form_field_7_mat_option_4_Template, 2, 2, "mat-option", 14);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r0 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngModel", ctx_r0.serieId);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngForOf", ctx_r0.series);
} }
function BookListComponent_mat_form_field_8_mat_option_4_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-option", 15);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const data_r21 = ctx.$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵpropertyInterpolate"]("value", data_r21.id);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate1"](" ", data_r21.name, " ");
} }
function BookListComponent_mat_form_field_8_Template(rf, ctx) { if (rf & 1) {
    const _r23 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-form-field", 12);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](1, "mat-label");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](2, "\u0421\u0435\u0437\u043E\u043D");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](3, "mat-select", 13);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("ngModelChange", function BookListComponent_mat_form_field_8_Template_mat_select_ngModelChange_3_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r23); const ctx_r22 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r22.seasonId = $event; })("ngModelChange", function BookListComponent_mat_form_field_8_Template_mat_select_ngModelChange_3_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r23); const ctx_r24 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r24.searchBooks(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](4, BookListComponent_mat_form_field_8_mat_option_4_Template, 2, 2, "mat-option", 14);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngModel", ctx_r1.seasonId);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngForOf", ctx_r1.seasons);
} }
function BookListComponent_mat_form_field_9_Template(rf, ctx) { if (rf & 1) {
    const _r26 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-form-field", 2);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](1, "mat-label");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](2, "\u0427\u0438\u0441\u043B\u043E \u0441\u0435\u0440\u0438\u0439");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](3, "input", 16);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("ngModelChange", function BookListComponent_mat_form_field_9_Template_input_ngModelChange_3_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r26); const ctx_r25 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r25.episodeCount = $event; });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r2 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngModel", ctx_r2.episodeCount);
} }
function BookListComponent_mat_form_field_10_mat_option_4_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-option", 15);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const topping_r28 = ctx.$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("value", topping_r28);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate"](topping_r28);
} }
function BookListComponent_mat_form_field_10_Template(rf, ctx) { if (rf & 1) {
    const _r30 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-form-field", 12);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](1, "mat-label");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](2, "\u0416\u0430\u043D\u0440\u044B");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](3, "mat-select", 17);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("valueChange", function BookListComponent_mat_form_field_10_Template_mat_select_valueChange_3_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r30); const ctx_r29 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r29.selectedGenres = $event; })("selectionChange", function BookListComponent_mat_form_field_10_Template_mat_select_selectionChange_3_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r30); const ctx_r31 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r31.watchedChanged($event); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](4, BookListComponent_mat_form_field_10_mat_option_4_Template, 2, 2, "mat-option", 14);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r3 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("value", ctx_r3.selectedGenres);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngForOf", ctx_r3.genres);
} }
function BookListComponent_mat_form_field_11_mat_option_4_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-option", 15);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const range_r33 = ctx.$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("value", range_r33);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate2"]("", range_r33.start, "-", range_r33.end, "");
} }
function BookListComponent_mat_form_field_11_Template(rf, ctx) { if (rf & 1) {
    const _r35 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-form-field", 12);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](1, "mat-label");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](2, "\u0413\u043E\u0434\u044B");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](3, "mat-select", 17);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("valueChange", function BookListComponent_mat_form_field_11_Template_mat_select_valueChange_3_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r35); const ctx_r34 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r34.selectedYears = $event; })("selectionChange", function BookListComponent_mat_form_field_11_Template_mat_select_selectionChange_3_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r35); const ctx_r36 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r36.watchedChanged($event); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](4, BookListComponent_mat_form_field_11_mat_option_4_Template, 2, 3, "mat-option", 14);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r4 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("value", ctx_r4.selectedYears);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngForOf", ctx_r4.yearsRange);
} }
function BookListComponent_mat_checkbox_13_Template(rf, ctx) { if (rf & 1) {
    const _r38 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-checkbox", 18);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("ngModelChange", function BookListComponent_mat_checkbox_13_Template_mat_checkbox_ngModelChange_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r38); const ctx_r37 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r37.isRandom = $event; });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1, "\u0421\u043B\u0443\u0447\u0430\u0439\u043D\u044B\u0439 \u043F\u043E\u0440\u044F\u0434\u043E\u043A");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r5 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngModel", ctx_r5.isRandom);
} }
function BookListComponent_mat_checkbox_14_Template(rf, ctx) { if (rf & 1) {
    const _r40 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-checkbox", 19);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("ngModelChange", function BookListComponent_mat_checkbox_14_Template_mat_checkbox_ngModelChange_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r40); const ctx_r39 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r39.showWatched = $event; })("change", function BookListComponent_mat_checkbox_14_Template_mat_checkbox_change_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r40); const ctx_r41 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r41.watchedChanged($event); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1, "\u041F\u043E\u043A\u0430\u0437\u0430\u0442\u044C \u043F\u0440\u043E\u0441\u043C\u043E\u0442\u0440\u0435\u043D\u043D\u043E\u0435");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r6 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngModel", ctx_r6.showWatched);
} }
function BookListComponent_mat_checkbox_15_Template(rf, ctx) { if (rf & 1) {
    const _r43 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-checkbox", 19);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("ngModelChange", function BookListComponent_mat_checkbox_15_Template_mat_checkbox_ngModelChange_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r43); const ctx_r42 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r42.showWatched = $event; })("change", function BookListComponent_mat_checkbox_15_Template_mat_checkbox_change_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r43); const ctx_r44 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r44.watchedChanged($event); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1, "\u041F\u043E\u043A\u0430\u0437\u0430\u0442\u044C \u043F\u0440\u043E\u0441\u043C\u043E\u0442\u0440\u0435\u043D\u043D\u043E\u0435");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r7 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngModel", ctx_r7.showWatched);
} }
function BookListComponent_mat_checkbox_16_Template(rf, ctx) { if (rf & 1) {
    const _r46 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-checkbox", 19);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("ngModelChange", function BookListComponent_mat_checkbox_16_Template_mat_checkbox_ngModelChange_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r46); const ctx_r45 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r45.showOnlyWebSupported = $event; })("change", function BookListComponent_mat_checkbox_16_Template_mat_checkbox_change_0_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r46); const ctx_r47 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r47.showFilteredBooks(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1, "\u0422\u043E\u043B\u044C\u043A\u043E \u0432 \u0431\u0440\u0430\u0443\u0437\u0435\u0440\u0435");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r8 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngModel", ctx_r8.showOnlyWebSupported);
} }
function BookListComponent_mat_checkbox_17_Template(rf, ctx) { if (rf & 1) {
    const _r49 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-checkbox", 19);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("ngModelChange", function BookListComponent_mat_checkbox_17_Template_mat_checkbox_ngModelChange_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r49); const ctx_r48 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r48.showSelected = $event; })("change", function BookListComponent_mat_checkbox_17_Template_mat_checkbox_change_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r49); const ctx_r50 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r50.watchedChanged($event); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1, "\u0422\u043E\u043B\u044C\u043A\u043E \u043E\u0442\u043E\u0431\u0440\u0430\u043D\u043D\u043E\u0435");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r9 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngModel", ctx_r9.showSelected);
} }
function BookListComponent_button_21_Template(rf, ctx) { if (rf & 1) {
    const _r52 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "button", 20);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("click", function BookListComponent_button_21_Template_button_click_0_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r52); const ctx_r51 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](); return ctx_r51.continueWatch(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1, "\u041F\u0440\u043E\u0434\u043E\u043B\u0436\u0438\u0442\u044C \u0432\u043E\u0441\u043F\u0440\u043E\u0438\u0437\u0432\u0435\u0434\u0435\u043D\u0438\u0435");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} }
const _c1 = function (a0) { return { shownFilm: a0 }; };
function BookListComponent_div_22_div_1_Template(rf, ctx) { if (rf & 1) {
    const _r56 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "div", 23);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](1, "mat-card", 24);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](2, "mat-card-header");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](3, "mat-card-title");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](4);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](5, "mat-card-subtitle");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](6);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](7, "img", 25);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("click", function BookListComponent_div_22_div_1_Template_img_click_7_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r56); const book_r54 = restoredCtx.$implicit; const ctx_r55 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](2); return ctx_r55.openVideo(book_r54); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const book_r54 = ctx.$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](4);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate"](book_r54.displayName);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate2"]("", book_r54.hours, " ", book_r54.durationMinutes % 60, " \u043C\u0438\u043D\u0443\u0442");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵpropertyInterpolate"]("src", book_r54.coverURL, _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵsanitizeUrl"]);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngClass", _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵpureFunction1"](5, _c1, book_r54.isFinished));
} }
function BookListComponent_div_22_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "div", 21);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](1, BookListComponent_div_22_div_1_Template, 8, 7, "div", 22);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r11 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngForOf", ctx_r11.books);
} }
function BookListComponent_div_23_div_1_mat_icon_3_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "mat-icon", 36);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1, "video_library");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} }
function BookListComponent_div_23_div_1_button_13_Template(rf, ctx) { if (rf & 1) {
    const _r63 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "button", 20);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("click", function BookListComponent_div_23_div_1_button_13_Template_button_click_0_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r63); const book_r58 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]().$implicit; const ctx_r61 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](2); return ctx_r61.copyLink(book_r58); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](1, "\u0421\u043A\u043E\u043F\u0438\u0440\u043E\u0432\u0430\u0442\u044C \u0441\u0441\u044B\u043B\u043A\u0443");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} }
function BookListComponent_div_23_div_1_Template(rf, ctx) { if (rf & 1) {
    const _r65 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "div", 23);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](1, "mat-card", 24);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](2, "mat-card-header");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](3, BookListComponent_div_23_div_1_mat_icon_3_Template, 2, 0, "mat-icon", 26);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](4, "mat-card-title");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](5);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](6, "mat-card-subtitle");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](7);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](8, "div", 27);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](9, "div", 28);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](10, "div", 29);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](11, "img", 25);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("click", function BookListComponent_div_23_div_1_Template_img_click_11_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r65); const book_r58 = restoredCtx.$implicit; const ctx_r64 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](2); return ctx_r64.openVideo(book_r58); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](12, "div", 30);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](13, BookListComponent_div_23_div_1_button_13_Template, 2, 0, "button", 9);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](14, "a", 31);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵpipe"](15, "safe");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](16, "button", 32);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("click", function BookListComponent_div_23_div_1_Template_button_click_16_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r65); const book_r58 = restoredCtx.$implicit; const ctx_r66 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](2); return ctx_r66.filmStarted(book_r58); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](17, "\u041E\u0442\u043A\u0440\u044B\u0442\u044C \u0444\u0438\u043B\u044C\u043C \u0432 VLC");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](18, "button", 33);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("click", function BookListComponent_div_23_div_1_Template_button_click_18_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r65); const book_r58 = restoredCtx.$implicit; const ctx_r67 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](2); const _r13 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵreference"](25); return ctx_r67.deleteFilm(_r13, book_r58); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](19, "\u0423\u0434\u0430\u043B\u0438\u0442\u044C \u0444\u0438\u043B\u044C\u043C");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](20, "button", 34);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("click", function BookListComponent_div_23_div_1_Template_button_click_20_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r65); const book_r58 = restoredCtx.$implicit; const ctx_r68 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](2); return ctx_r68.filmWatched(book_r58); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](21, "\u0424\u0438\u043B\u044C\u043C \u043F\u0440\u043E\u0441\u043C\u043E\u0442\u0440\u0435\u043D");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelement"](22, "br");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](23, "mat-checkbox", 35);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("ngModelChange", function BookListComponent_div_23_div_1_Template_mat_checkbox_ngModelChange_23_listener($event) { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r65); const book_r58 = restoredCtx.$implicit; return book_r58.isSelected = $event; });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](24, "\u041E\u0442\u043E\u0431\u0440\u0430\u0442\u044C");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelement"](25, "br");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelement"](26, "br");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](27, "div");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](28);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵpipe"](29, "slice");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelement"](30, "br");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](31, "div");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](32);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelement"](33, "br");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](34, "div");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](35);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelement"](36, "br");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](37, "div");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](38);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelement"](39, "br");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const book_r58 = ctx.$implicit;
    const ctx_r57 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", book_r58.isSupportedWebPlayer);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate1"]("", book_r58.displayName, " ");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate2"]("", book_r58.hours, " ", book_r58.durationMinutes % 60, " \u043C\u0438\u043D\u0443\u0442");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](4);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵpropertyInterpolate"]("src", book_r58.coverURL, _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵsanitizeUrl"]);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngClass", _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵpureFunction1"](19, _c1, book_r58.isFinished));
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", !ctx_r57.isAndroid);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("href", _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵpipeBind1"](15, 13, book_r58.PlayURL), _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵsanitizeUrl"]);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](9);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngModel", book_r58.isSelected);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](5);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate"](_angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵpipeBind3"](29, 15, book_r58.description, 0, 350));
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](4);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate"](book_r58.year);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate"](book_r58.genres);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtextInterpolate"](book_r58.director);
} }
function BookListComponent_div_23_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "div", 21);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](1, BookListComponent_div_23_div_1_Template, 40, 21, "div", 22);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r12 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngForOf", ctx_r12.books);
} }
function BookListComponent_ng_template_24_Template(rf, ctx) { if (rf & 1) {
    const _r72 = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "div", 37);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](1, "h4", 38);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](2, "Modal title");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](3, "button", 39);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("click", function BookListComponent_ng_template_24_Template_button_click_3_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r72); const modal_r70 = restoredCtx.$implicit; return modal_r70.dismiss("Cross click"); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](4, "div", 40);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](5, "p");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](6, "One fine body\u2026");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](7, "div", 41);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](8, "button", 42);
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("click", function BookListComponent_ng_template_24_Template_button_click_8_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵrestoreView"](_r72); const modal_r70 = restoredCtx.$implicit; return modal_r70.close("Close click"); });
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](9, "Close");
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
} }
class YearsRange {
}
class BookListComponent {
    constructor(router, service, seriesService, sanitizer, toastr, http, modalService, spinner, activatedRoute, confirmationDialogService) {
        this.router = router;
        this.service = service;
        this.seriesService = seriesService;
        this.sanitizer = sanitizer;
        this.toastr = toastr;
        this.http = http;
        this.modalService = modalService;
        this.spinner = spinner;
        this.activatedRoute = activatedRoute;
        this.confirmationDialogService = confirmationDialogService;
        this.isRandom = false;
        this.showWatched = true;
        this.showSelected = false;
        this.showWatchedCheckbox = false;
        this.isSelectSeries = false;
        this.isSelectSeason = false;
        this.showKPINfo = false;
        this.serieId = 0;
        this.seasonId = 0;
        this.searchTitle = '';
        this.episodeCount = 1;
        this.searchValueChanged = new rxjs__WEBPACK_IMPORTED_MODULE_6__.Subject();
        this.selected = [];
        this.yearsRange = [{ start: 0, end: 1950 },
            { start: 1951, end: 1970 },
            { start: 1971, end: 1980 },
            { start: 1981, end: 1990 },
            { start: 1991, end: 2000 },
            { start: 2001, end: 2010 },
            { start: 2011, end: 2030 }].reverse();
        this.genres = ['комедия', 'драма', 'боевик', 'детектив', 'фантастика', 'биография', 'фэнтези', 'приключения', 'мелодрама'];
        this._numberOfTry = 0;
        this.counter = 0;
        this.activatedRoute.queryParams.subscribe(params => {
            console.log(params['type']);
            // let value = params['type'];
            // var color : VideoType = value as unknown as VideoType;
        });
    }
    ngOnInit() {
        setTimeout(() => this.showSpinner(), 5);
        this.type = (this.activatedRoute.snapshot.paramMap.get('type'));
        this.displayListForType();
        this.searchValueChanged.pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_7__.debounceTime)(1000))
            .subscribe(() => {
            this.search();
        });
        this.detectOs();
    }
    detectOs() {
        let os = this.getOS();
        if (os == "Android")
            this.isAndroid = true;
    }
    getOS() {
        var uA = navigator.userAgent || navigator.vendor;
        if ((/iPad|iPhone|iPod/.test(uA) && !window.MSStream) || (uA.includes('Mac') && 'ontouchend' in document))
            return 'iOS';
        var i, os = ['Windows', 'Android', 'Unix', 'Mac', 'Linux', 'BlackBerry'];
        for (i = 0; i < os.length; i++)
            if (new RegExp(os[i], 'i').test(uA))
                return os[i];
    }
    getSeries(type) {
        this.seriesService.getAll(type).subscribe(series => {
            this.series = series.sort((a, b) => {
                return a.name >= b.name
                    ? 1
                    : -1;
            });
            this.hideSpinner();
            // this.serieId = 6091;
            this.searchBooks();
        });
    }
    addBook() {
        this.router.navigate(['/book']);
    }
    editBook(bookId) {
        this.router.navigate(['/book/' + bookId]);
    }
    filmWatched(film) {
        // this.service.filmWatched(film.id).subscribe(
        //   () => {},
        //   err => {
        //     this.toastr.error('Ошибка.');
        //   });
        this.service.setPosition(film.id, 100000);
    }
    deleteBook(bookId) {
        this.confirmationDialogService.confirm('Atention', 'Do you really want to delete this book?')
            .then(() => this.service.deleteBook(bookId).subscribe(() => {
            this.toastr.success('The book has been deleted');
            // this.getValues();
        }, err => {
            this.toastr.error('Failed to delete the book.');
        }))
            .catch(() => '');
    }
    searchBooks() {
        this.searchValueChanged.next();
    }
    copyLink(file) {
        this.copyToClipboard(this.service.getVideoURLById(file.id));
    }
    copyToClipboard(text) {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(text);
        }
        else {
            alert(text);
        }
    }
    search() {
        this.showSpinner();
        if (this.searchTitle !== '') {
            this.service.searchFilesWithTitle(this.searchTitle).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
        }
        else if (this.seasonId != 0) {
            this.service.searchFilesWithSeason(this.seasonId, this.isRandom).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
        }
        else if (this.serieId != 0) {
            let serie = this.series.filter(x => x.id == this.serieId)[0];
            this.seasons = serie.seasons;
            this.service.searchFilesWithSeries(serie.name, this.isRandom).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
        }
        else {
            this.hideSpinner();
            // this.toastr.error('Выберите название файла или сериала');
        }
    }
    displayListForType() {
        let that = this;
        switch (this.type) {
            case 'series': {
                this.selectSeries(true);
                this.getSeries(src_app_models_Book__WEBPACK_IMPORTED_MODULE_0__.VideoType.ChildEpisode);
                break;
            }
            case 'youtube': {
                this.isRandom = false;
                this.isSelectSeason = true;
                this.showWatchedCheckbox = true;
                this.showWatched = false;
                this.serieId = 6091;
                this.getSeries(src_app_models_Book__WEBPACK_IMPORTED_MODULE_0__.VideoType.Youtube);
                this.episodeCount = 10;
                break;
            }
            case 'soviet': {
                this.selectSeries(true);
                this.series = [];
                this.series.push({ id: 13, name: 'Известные', seasons: [] });
                this.series.push({ id: 14, name: 'Разные', seasons: [] });
                this.series.push({ id: 16, name: 'Мультсериалы', seasons: [] });
                this.service.getSovietAnimation().subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
                ;
                break;
            }
            case 'other': {
                this.seriesService.getOther().subscribe(series => {
                    this.series = series;
                    this.selectSeries(true);
                    this.hideSpinner();
                    this.isRandom = false;
                    this.episodeCount = 10;
                    // Harcode for Youtube
                    // this.serieId = 6091;
                    // this.seasonId = 13469;
                    // this.searchBooks();
                });
                break;
            }
            case 'sovietfairytale': {
                this.service.getFilmsByType(src_app_models_Book__WEBPACK_IMPORTED_MODULE_0__.VideoType.FairyTale).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
                ;
                break;
            }
            case 'animation': {
                this.service.getBigAnimation().subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
                ;
                break;
            }
            case 'balley': {
                this.videoType = src_app_models_Book__WEBPACK_IMPORTED_MODULE_0__.VideoType.Art;
                this.isRandom = false;
                this.episodeCount = 1000;
                this.service.getFilmsByTypeUniqueSeason(src_app_models_Book__WEBPACK_IMPORTED_MODULE_0__.VideoType.Art).subscribe(this.showBooks.bind(this), this.getFilmsError.bind(this));
                ;
                break;
            }
            case 'film': {
                this.showSpinner();
                this.selectSeries(true);
                this.showWatched = false;
                this.getSeries(src_app_models_Book__WEBPACK_IMPORTED_MODULE_0__.VideoType.Film);
                this.service.getFilmsByType(src_app_models_Book__WEBPACK_IMPORTED_MODULE_0__.VideoType.Film).subscribe({
                    next: (books) => that.showBooks(books),
                    error: (e) => this.getFilmsError(e)
                });
                this.showKPINfo = true;
                break;
            }
            case 'latest': {
                this.showSpinner();
                this.selectSeries(false);
                this.showWatched = true;
                this.service.getLatest().subscribe({
                    next: (books) => {
                        that.showBooks(books);
                        this.hideSpinner();
                    },
                    error: (e) => this.getFilmsError(e)
                });
                break;
            }
        }
    }
    selectSeries(value) {
        this.isSelectSeries = value;
        this.isSelectSeason = value;
    }
    watchedChanged(event) {
        this.showFilteredBooks();
    }
    deleteFilm(content, film) {
        let that = this;
        if (window.confirm("Фильм будет удален из базы и с диска?")) {
            this.service.deleteBook(film.id).subscribe(x => that.displayListForType());
        }
        // this.modalService.open(content, { centered: true });
        // this.toastr.warning('Выберите название файла или сериала');
    }
    showBooks(books) {
        this.apibooks = books;
        this.showFilteredBooks();
    }
    showFilteredBooks() {
        let books = this.apibooks;
        if (this.showSelected)
            books = books.filter(x => x.isSelected);
        if (!this.showWatched)
            books = books.filter(x => !x.isFinished);
        if (this.type != 'film')
            this.books = books;
        else {
            if (this.showOnlyWebSupported)
                books = books.filter(x => x.isSupportedWebPlayer);
            this.books = books.sort((a, b) => {
                if (a.year > b.year)
                    return -1;
                else if (a.year == b.year)
                    return 0;
                else
                    return 1;
            });
            if (this.selectedGenres) {
                this.books = this.books.filter(book => {
                    var haveGenre = false;
                    this.selectedGenres.forEach(genre => {
                        var _a;
                        if (((_a = book.genres) === null || _a === void 0 ? void 0 : _a.toLowerCase().indexOf(genre.toLowerCase())) != -1) {
                            haveGenre = true;
                            return;
                        }
                    });
                    return haveGenre;
                });
            }
            if (this.selectedYears) {
                this.books = this.books.filter(book => {
                    var isInRange = false;
                    this.selectedYears.forEach(range => {
                        if (book.year >= range.start && book.year <= range.end)
                            isInRange = true;
                        return;
                    });
                    return isInRange;
                });
            }
        }
        this.books.forEach(book => {
            book.PlayURL = (`vlc://${this.service.getVideoURLById(book.id)}`);
            book.coverURL = (`${this.service.getVideoCoverById(book.id)}`);
            let hours = Math.floor(book.durationMinutes / 60);
            if (hours > 0) {
                let ending = hours == 1 ? '' : 'а';
                book.hours = hours.toString() + " час" + ending;
            }
        });
        this.hideSpinner();
    }
    filmStarted(book) {
        this.service.filmStarted(book.id).subscribe();
    }
    getFilmsError(error) {
        if (this._numberOfTry++ < 10)
            this.displayListForType();
        else {
            this.hideSpinner();
            this.books = [];
        }
    }
    hideSpinner() {
        setTimeout(() => {
            this.counter--;
            if (this.counter < 0)
                this.counter = 0;
            if (this.counter == 0)
                this.spinner.hide();
        }, 5);
    }
    showSpinner() {
        this.counter++;
        this.spinner.show();
    }
    continueWatch() {
        var film = this.books.find(x => !x.isFinished);
        this.openVideo(film);
    }
    openVideo(book) {
        if (!book.isSupportedWebPlayer) {
            window.open(`vlc://${this.service.getVideoURLById(book.id)}`, "_blank");
            return;
        }
        let showDelete = this.type != 'soviet' && this.type != 'sovietfairytale' && this.type != 'series';
        const queryParams = {
            seriesId: book.seriesId,
            videoId: book.id,
            videosCount: this.episodeCount,
            isRandom: this.isRandom,
            seasonId: 0,
            type: this.type,
            showDeleteButton: showDelete
        };
        if (this.videoType == src_app_models_Book__WEBPACK_IMPORTED_MODULE_0__.VideoType.Art)
            queryParams.seasonId = book.seasonId;
        const navigationExtras = {
            queryParams
        };
        this.router.navigate(['/player'], navigationExtras);
    }
}
BookListComponent.ɵfac = function BookListComponent_Factory(t) { return new (t || BookListComponent)(_angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdirectiveInject"](_angular_router__WEBPACK_IMPORTED_MODULE_8__.Router), _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdirectiveInject"](src_app_services_file_service__WEBPACK_IMPORTED_MODULE_1__.FileService), _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdirectiveInject"](src_app_services_series_service__WEBPACK_IMPORTED_MODULE_2__.SeriesService), _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdirectiveInject"](_angular_platform_browser__WEBPACK_IMPORTED_MODULE_9__.DomSanitizer), _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdirectiveInject"](ngx_toastr__WEBPACK_IMPORTED_MODULE_10__.ToastrService), _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdirectiveInject"](_angular_common_http__WEBPACK_IMPORTED_MODULE_11__.HttpClient), _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdirectiveInject"](_ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_12__.NgbModal), _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdirectiveInject"](ngx_spinner__WEBPACK_IMPORTED_MODULE_13__.NgxSpinnerService), _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdirectiveInject"](_angular_router__WEBPACK_IMPORTED_MODULE_8__.ActivatedRoute), _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdirectiveInject"](src_app_services_confirmation_dialog_service__WEBPACK_IMPORTED_MODULE_3__.ConfirmationDialogService)); };
BookListComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdefineComponent"]({ type: BookListComponent, selectors: [["app-book-list"]], viewQuery: function BookListComponent_Query(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵviewQuery"](_c0, 5);
    } if (rf & 2) {
        let _t;
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵqueryRefresh"](_t = _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵloadQuery"]()) && (ctx.video = _t.first);
    } }, decls: 26, vars: 14, consts: [[1, "col-md-12"], ["type", "ball-scale-multiple"], ["appearance", "fill", 1, "example-full-width"], ["matInput", "", 3, "ngModel", "ngModelChange"], ["appearance", "fill", 4, "ngIf"], ["class", "example-full-width", "appearance", "fill", 4, "ngIf"], ["class", "ml-2", 3, "ngModel", "ngModelChange", 4, "ngIf"], ["class", "ml-2", 3, "ngModel", "ngModelChange", "change", 4, "ngIf"], ["mat-icon-button", "", "color", "primary", 3, "click"], ["class", "btn btn-outline-primary btn-sm", 3, "click", 4, "ngIf"], ["fxLayout", "row wrap", "fxLayoutGap", "16px", 4, "ngIf"], ["content", ""], ["appearance", "fill"], [3, "ngModel", "ngModelChange"], [3, "value", 4, "ngFor", "ngForOf"], [3, "value"], ["matInput", "", "type", "number", 3, "ngModel", "ngModelChange"], ["multiple", "", 3, "value", "valueChange", "selectionChange"], [1, "ml-2", 3, "ngModel", "ngModelChange"], [1, "ml-2", 3, "ngModel", "ngModelChange", "change"], [1, "btn", "btn-outline-primary", "btn-sm", 3, "click"], ["fxLayout", "row wrap", "fxLayoutGap", "16px"], ["fxFlex", "48%", "fxFlex.xs", "100%", 4, "ngFor", "ngForOf"], ["fxFlex", "48%", "fxFlex.xs", "100%"], [1, "mat-elevation-z4", "mt-2"], ["loading", "lazy", 3, "ngClass", "src", "click"], ["mat-card-avatar", "", 4, "ngIf"], [1, "container"], [1, "row"], [1, "col-sm-8"], [1, "col-sm"], [3, "href"], [1, "btn", "btn-outline-warning", "btn-sm", 2, "margin-top", "0.5rem", 3, "click"], [1, "btn", "btn-outline-danger", "btn-sm", "mt-2", 3, "click"], [1, "btn", "btn-outline-success", "btn-sm", "mt-2", 3, "click"], [1, "mt-2", 3, "ngModel", "ngModelChange"], ["mat-card-avatar", ""], [1, "modal-header"], [1, "modal-title"], ["type", "button", "aria-label", "Close", 1, "btn-close", 3, "click"], [1, "modal-body"], [1, "modal-footer"], ["type", "button", 1, "btn", "btn-light", 3, "click"]], template: function BookListComponent_Template(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](0, "div", 0);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelement"](1, "ngx-spinner", 1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](2, "div");
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](3, "mat-form-field", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](4, "mat-label");
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](5, "\u041D\u0430\u0437\u0432\u0430\u043D\u0438\u0435");
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](6, "input", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("ngModelChange", function BookListComponent_Template_input_ngModelChange_6_listener($event) { return ctx.searchTitle = $event; })("ngModelChange", function BookListComponent_Template_input_ngModelChange_6_listener() { return ctx.searchBooks(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](7, BookListComponent_mat_form_field_7_Template, 5, 2, "mat-form-field", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](8, BookListComponent_mat_form_field_8_Template, 5, 2, "mat-form-field", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](9, BookListComponent_mat_form_field_9_Template, 4, 1, "mat-form-field", 5);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](10, BookListComponent_mat_form_field_10_Template, 5, 2, "mat-form-field", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](11, BookListComponent_mat_form_field_11_Template, 5, 2, "mat-form-field", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](12, "div");
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](13, BookListComponent_mat_checkbox_13_Template, 2, 1, "mat-checkbox", 6);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](14, BookListComponent_mat_checkbox_14_Template, 2, 1, "mat-checkbox", 7);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](15, BookListComponent_mat_checkbox_15_Template, 2, 1, "mat-checkbox", 7);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](16, BookListComponent_mat_checkbox_16_Template, 2, 1, "mat-checkbox", 7);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](17, BookListComponent_mat_checkbox_17_Template, 2, 1, "mat-checkbox", 7);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](18, "button", 8);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵlistener"]("click", function BookListComponent_Template_button_click_18_listener() { return ctx.searchBooks(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementStart"](19, "mat-icon");
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtext"](20, "refresh");
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](21, BookListComponent_button_21_Template, 2, 0, "button", 9);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](22, BookListComponent_div_22_Template, 2, 1, "div", 10);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](23, BookListComponent_div_23_Template, 2, 1, "div", 10);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplate"](24, BookListComponent_ng_template_24_Template, 10, 0, "ng-template", null, 11, _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵtemplateRefExtractor"]);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵelementEnd"]();
    } if (rf & 2) {
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](6);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngModel", ctx.searchTitle);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.isSelectSeries);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.isSelectSeason);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.isSelectSeries);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.showKPINfo);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.showKPINfo);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.isSelectSeries && !ctx.showKPINfo);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.showWatchedCheckbox);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.showKPINfo);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.showKPINfo);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.showKPINfo);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](4);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", !ctx.isRandom);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", !ctx.showKPINfo);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵproperty"]("ngIf", ctx.showKPINfo);
    } }, directives: [ngx_spinner__WEBPACK_IMPORTED_MODULE_13__.NgxSpinnerComponent, _angular_material_form_field__WEBPACK_IMPORTED_MODULE_14__.MatFormField, _angular_material_form_field__WEBPACK_IMPORTED_MODULE_14__.MatLabel, _angular_material_input__WEBPACK_IMPORTED_MODULE_15__.MatInput, _angular_forms__WEBPACK_IMPORTED_MODULE_16__.DefaultValueAccessor, _angular_forms__WEBPACK_IMPORTED_MODULE_16__.NgControlStatus, _angular_forms__WEBPACK_IMPORTED_MODULE_16__.NgModel, _angular_common__WEBPACK_IMPORTED_MODULE_17__.NgIf, _angular_material_select__WEBPACK_IMPORTED_MODULE_18__.MatSelect, _angular_common__WEBPACK_IMPORTED_MODULE_17__.NgForOf, _angular_material_core__WEBPACK_IMPORTED_MODULE_19__.MatOption, _angular_forms__WEBPACK_IMPORTED_MODULE_16__.NumberValueAccessor, _angular_material_checkbox__WEBPACK_IMPORTED_MODULE_20__.MatCheckbox, _angular_material_button__WEBPACK_IMPORTED_MODULE_21__.MatButton, _angular_material_icon__WEBPACK_IMPORTED_MODULE_22__.MatIcon, _angular_flex_layout_flex__WEBPACK_IMPORTED_MODULE_23__.DefaultLayoutDirective, _angular_flex_layout_flex__WEBPACK_IMPORTED_MODULE_23__.DefaultLayoutGapDirective, _angular_flex_layout_flex__WEBPACK_IMPORTED_MODULE_23__.DefaultFlexDirective, _angular_material_card__WEBPACK_IMPORTED_MODULE_24__.MatCard, _angular_material_card__WEBPACK_IMPORTED_MODULE_24__.MatCardHeader, _angular_material_card__WEBPACK_IMPORTED_MODULE_24__.MatCardTitle, _angular_material_card__WEBPACK_IMPORTED_MODULE_24__.MatCardSubtitle, _angular_common__WEBPACK_IMPORTED_MODULE_17__.NgClass, _angular_flex_layout_extended__WEBPACK_IMPORTED_MODULE_25__.DefaultClassDirective, _angular_material_card__WEBPACK_IMPORTED_MODULE_24__.MatCardAvatar], pipes: [_services_SafePipe__WEBPACK_IMPORTED_MODULE_4__.SafePipe, _angular_common__WEBPACK_IMPORTED_MODULE_17__.SlicePipe], styles: [".jumbtron {\r\n    padding-top: 60px;\r\n}\r\n\r\nimg {\r\n    cursor: pointer;\r\n    max-width: 100%;\r\n }\r\n\r\n.shownFilm{\r\n     opacity: 0.5;\r\n }\r\n\r\nlabel {\r\n    margin-bottom: 0;\r\n}\r\n\r\nimg{\r\n    max-height: 550px;\r\n}\r\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbImJvb2stbGlzdC5jb21wb25lbnQuY3NzIl0sIm5hbWVzIjpbXSwibWFwcGluZ3MiOiJBQUFBO0lBQ0ksaUJBQWlCO0FBQ3JCOztBQUVBO0lBQ0ksZUFBZTtJQUNmLGVBQWU7Q0FDbEI7O0FBRUE7S0FDSSxZQUFZO0NBQ2hCOztBQUVBO0lBQ0csZ0JBQWdCO0FBQ3BCOztBQUdBO0lBQ0ksaUJBQWlCO0FBQ3JCIiwiZmlsZSI6ImJvb2stbGlzdC5jb21wb25lbnQuY3NzIiwic291cmNlc0NvbnRlbnQiOlsiLmp1bWJ0cm9uIHtcclxuICAgIHBhZGRpbmctdG9wOiA2MHB4O1xyXG59XHJcblxyXG5pbWcge1xyXG4gICAgY3Vyc29yOiBwb2ludGVyO1xyXG4gICAgbWF4LXdpZHRoOiAxMDAlO1xyXG4gfVxyXG5cclxuIC5zaG93bkZpbG17XHJcbiAgICAgb3BhY2l0eTogMC41O1xyXG4gfVxyXG5cclxuIGxhYmVsIHtcclxuICAgIG1hcmdpbi1ib3R0b206IDA7XHJcbn1cclxuXHJcblxyXG5pbWd7XHJcbiAgICBtYXgtaGVpZ2h0OiA1NTBweDtcclxufSJdfQ== */", "\n    .dark-modal .modal-content {\n      background-color: #292b2c;\n      color: white;\n    }\n    .dark-modal .close {\n      color: white;\n    }\n    .light-blue-backdrop {\n      background-color: #5cb3fd;\n    }\n  \n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbImJvb2stbGlzdC5jb21wb25lbnQudHMiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IjtJQUNJO01BQ0UseUJBQXlCO01BQ3pCLFlBQVk7SUFDZDtJQUNBO01BQ0UsWUFBWTtJQUNkO0lBQ0E7TUFDRSx5QkFBeUI7SUFDM0IiLCJmaWxlIjoiYm9vay1saXN0LmNvbXBvbmVudC50cyIsInNvdXJjZXNDb250ZW50IjpbIlxuICAgIC5kYXJrLW1vZGFsIC5tb2RhbC1jb250ZW50IHtcbiAgICAgIGJhY2tncm91bmQtY29sb3I6ICMyOTJiMmM7XG4gICAgICBjb2xvcjogd2hpdGU7XG4gICAgfVxuICAgIC5kYXJrLW1vZGFsIC5jbG9zZSB7XG4gICAgICBjb2xvcjogd2hpdGU7XG4gICAgfVxuICAgIC5saWdodC1ibHVlLWJhY2tkcm9wIHtcbiAgICAgIGJhY2tncm91bmQtY29sb3I6ICM1Y2IzZmQ7XG4gICAgfVxuICAiXX0= */"], encapsulation: 2 });
class PlayerParameters {
    static parse(json) {
        var data = JSON.parse(json);
        const obj = {
            videoId: Number(data.videoId),
            seriesId: Number(data.seriesId),
            seasonId: Number(data.seasonId),
            videosCount: Number(data.videosCount),
            isRandom: (data.isRandom === "true"),
            showDeleteButton: (data.showDeleteButton === "true"),
            type: data.type,
        };
        return obj;
    }
}


/***/ }),

/***/ 2836:
/*!**************************************************!*\
  !*** ./src/app/books/player/player.component.ts ***!
  \**************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "PlayerComponent": () => (/* binding */ PlayerComponent)
/* harmony export */ });
/* harmony import */ var moment__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! moment */ 6908);
/* harmony import */ var moment__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(moment__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var src_app_models_SeekPosition__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! src/app/_models/SeekPosition */ 9248);
/* harmony import */ var _book_list_book_list_component__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../book-list/book-list.component */ 2495);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var src_app_services_file_service__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! src/app/_services/file.service */ 5878);
/* harmony import */ var src_app_services_series_service__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! src/app/_services/series.service */ 8422);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! @angular/router */ 2816);
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! @angular/common */ 6362);
/* harmony import */ var ngx_toastr__WEBPACK_IMPORTED_MODULE_11__ = __webpack_require__(/*! ngx-toastr */ 2808);
/* harmony import */ var _angular_material_button__WEBPACK_IMPORTED_MODULE_12__ = __webpack_require__(/*! @angular/material/button */ 7317);
/* harmony import */ var _angular_material_icon__WEBPACK_IMPORTED_MODULE_13__ = __webpack_require__(/*! @angular/material/icon */ 5590);
/* harmony import */ var _markslist_markslist_component__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ../../markslist/markslist.component */ 7823);
/* harmony import */ var _positionslist_positionslist_component__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ../../positionslist/positionslist.component */ 9140);
/* harmony import */ var _angular_material_form_field__WEBPACK_IMPORTED_MODULE_14__ = __webpack_require__(/*! @angular/material/form-field */ 4770);
/* harmony import */ var _angular_material_input__WEBPACK_IMPORTED_MODULE_15__ = __webpack_require__(/*! @angular/material/input */ 3365);
/* harmony import */ var _angular_forms__WEBPACK_IMPORTED_MODULE_16__ = __webpack_require__(/*! @angular/forms */ 587);
/* harmony import */ var _services_SafePipe__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! ../../_services/SafePipe */ 1947);

















const _c0 = ["videoElement"];
const _c1 = ["markslist"];
function PlayerComponent_img_18_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelement"](0, "img", 9);
} }
function PlayerComponent_div_19_video_1_Template(rf, ctx) { if (rf & 1) {
    const _r11 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](0, "video", 39, 40);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("dblclick", function PlayerComponent_div_19_video_1_Template_video_dblclick_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r11); const ctx_r10 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2); return ctx_r10.doubleClickHandler($event); })("click", function PlayerComponent_div_19_video_1_Template_video_click_0_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r11); const ctx_r12 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2); return ctx_r12.startPlay(); })("ended", function PlayerComponent_div_19_video_1_Template_video_ended_0_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r11); const ctx_r13 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2); return ctx_r13.videoEnded(); })("seeked", function PlayerComponent_div_19_video_1_Template_video_seeked_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r11); const ctx_r14 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2); return ctx_r14.seeking($event); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelement"](2, "source", 41);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r2 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵpropertyInterpolate"]("src", ctx_r2.videoURL, _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵsanitizeUrl"]);
} }
function PlayerComponent_div_19_video_2_Template(rf, ctx) { if (rf & 1) {
    const _r17 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](0, "video", 42, 40);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("ended", function PlayerComponent_div_19_video_2_Template_video_ended_0_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r17); const ctx_r16 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2); return ctx_r16.videoEnded(); })("seeked", function PlayerComponent_div_19_video_2_Template_video_seeked_0_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r17); const ctx_r18 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2); return ctx_r18.seeking($event); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelement"](2, "source", 41);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r3 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵpropertyInterpolate"]("src", ctx_r3.videoURL, _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵsanitizeUrl"]);
} }
function PlayerComponent_div_19_button_25_Template(rf, ctx) { if (rf & 1) {
    const _r20 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](0, "button", 43);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_div_19_button_25_Template_button_click_0_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r20); const ctx_r19 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2); return ctx_r19.showDeleteModal(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](1, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](2, "delete");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
} }
function PlayerComponent_div_19_div_42_Template(rf, ctx) { if (rf & 1) {
    const _r22 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](0, "div");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](1, "button", 5);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_div_19_div_42_Template_button_click_1_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r22); const ctx_r21 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2); return ctx_r21.moveToBad(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](2, " \u0412 \u043F\u043B\u043E\u0445\u0438\u0435 ");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](3, "button", 6);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_div_19_div_42_Template_button_click_3_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r22); const ctx_r23 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2); return ctx_r23.moveToGood(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](4, " \u0412 \u0445\u043E\u0440\u043E\u0448\u0438\u0435 ");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
} }
function PlayerComponent_div_19_div_59_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](0, "div");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵpipe"](2, "date");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r8 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtextInterpolate1"](" \u041E\u0441\u0442\u0430\u043B\u043E\u0441\u044C \u0434\u043E \u043E\u0441\u0442\u0430\u043D\u043E\u0432\u043A\u0438: ", _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵpipeBind2"](2, 1, ctx_r8.timeLeft * 1000, "mm:ss"), " ");
} }
function PlayerComponent_div_19_Template(rf, ctx) { if (rf & 1) {
    const _r25 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](0, "div", 10);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtemplate"](1, PlayerComponent_div_19_video_1_Template, 3, 1, "video", 11);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtemplate"](2, PlayerComponent_div_19_video_2_Template, 3, 1, "video", 12);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](3, "div", 13);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](4, "div", 14);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](5, "i", 15);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](6, "\u25C0\u25C0\u25C0");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](7, "span", 16);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](8, "10 seconds");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](9, "div", 17);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](10, "div", 18);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](11, "i", 19);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](12, "\u25B6\u25B6\u25B6");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](13, "span", 20);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](14, "10 seconds");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](15, "div", 21);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](16, "button", 22);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_div_19_Template_button_click_16_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r25); const ctx_r24 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](); return ctx_r24.skipVideo(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](17, " \u0421\u043B\u0435\u0434\u0443\u044E\u0449\u0435\u0435 \u0432\u0438\u0434\u0435\u043E ");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](18, "a", 23);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵpipe"](19, "safe");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](20, "button", 24);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](21, " \u041E\u0442\u043A\u0440\u044B\u0442\u044C \u0444\u0438\u043B\u044C\u043C \u0432 VLC ");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](22, "button", 25);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](23, "mat-icon", 26);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_div_19_Template_mat_icon_click_23_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r25); const ctx_r26 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](); return ctx_r26.copyLink(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](24, "file_copy");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtemplate"](25, PlayerComponent_div_19_button_25_Template, 3, 0, "button", 27);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](26, "button", 28);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_div_19_Template_button_click_26_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r25); const ctx_r27 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](); return ctx_r27.rewindVideo(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](27, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](28, "fast_rewind");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](29, "button", 28);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_div_19_Template_button_click_29_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r25); const ctx_r28 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](); return ctx_r28.startPlay(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](30, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](31, "pause");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](32, "button", 28);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_div_19_Template_button_click_32_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r25); const ctx_r29 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](); return ctx_r29.forwardVideo(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](33, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](34, "fast_forward");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](35, "button", 28);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_div_19_Template_button_click_35_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r25); const ctx_r30 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](); return ctx_r30.switchToFullscreen(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](36, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](37, "fullscreen");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](38, "a", 29);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](39, "button", 30);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](40, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](41, "home");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtemplate"](42, PlayerComponent_div_19_div_42_Template, 5, 0, "div", 31);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelement"](43, "app-markslist", 32, 33);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelement"](45, "app-positionslist", 34, 35);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](47, "h2");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](48);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](49, "div");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](50);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelement"](51, "div");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](52, "mat-form-field", 36);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](53, "mat-label");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](54, "\u0412\u044B\u043A\u043B\u044E\u0447\u0438\u0442\u044C \u0447\u0435\u0440\u0435\u0437 (\u043C\u0438\u043D\u0443\u0442)");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](55, "input", 37);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("ngModelChange", function PlayerComponent_div_19_Template_input_ngModelChange_55_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r25); const ctx_r31 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](); return ctx_r31.timerMinutes = $event; })("keyup.enter", function PlayerComponent_div_19_Template_input_keyup_enter_55_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r25); const ctx_r32 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](); return ctx_r32.setTimer(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](56, "button", 38);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_div_19_Template_button_click_56_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵrestoreView"](_r25); const ctx_r33 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"](); return ctx_r33.setTimer(); });
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](57, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](58, "alarm_on");
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtemplate"](59, PlayerComponent_div_19_div_59_Template, 3, 4, "div", 31);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("ngIf", ctx_r1.isMobile);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("ngIf", !ctx_r1.isMobile);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](16);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("href", _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵpipeBind1"](19, 11, ctx_r1.vlcPlayURL), _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵsanitizeUrl"]);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](7);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("ngIf", ctx_r1.parameters.showDeleteButton);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](17);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("ngIf", ctx_r1.isSovietAnimation);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("videoId", ctx_r1.videoId);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("positions", ctx_r1.seekPositions);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtextInterpolate"](ctx_r1.name);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtextInterpolate"](ctx_r1.statStr);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](5);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("ngModel", ctx_r1.timerMinutes);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](4);
    _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("ngIf", ctx_r1.timeLeft);
} }
class PlayerComponent {
    constructor(service, categoryService, router, location, route, toastr) {
        this.service = service;
        this.categoryService = categoryService;
        this.router = router;
        this.location = location;
        this.route = route;
        this.toastr = toastr;
        this.previousVideoTimePlayed = moment__WEBPACK_IMPORTED_MODULE_0__.unix(0);
        this.playedVideoCount = 0;
        this.videosList = [];
        this.currentVideoIndex = -1;
        this.lastVolumeChangedTime = new Date(1);
        this.forwardSpeed = 0;
        this.rewindSpeed = 0;
        this.rewindNotificationValue = document.querySelector('.video-rewind-notify span');
        this.forwardNotificationValue = document.querySelector('.video-forward-notify span');
        this.seekPositions = new src_app_models_SeekPosition__WEBPACK_IMPORTED_MODULE_1__.SeekPositionCollection();
    }
    ngOnDestroy() {
        clearInterval(this.intervalId);
    }
    ngOnInit() {
        this.isMobile =
            /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        this.parameters = _book_list_book_list_component__WEBPACK_IMPORTED_MODULE_2__.PlayerParameters.parse(JSON.stringify(this.route.snapshot.queryParamMap.params));
        this.videoId = this.parameters.videoId;
        this.isSovietAnimation = this.parameters.type == 'soviet';
        this.isRandom = String(this.parameters.isRandom) === 'true';
        this.videosList.push(this.videoId);
        this.setNextVideo(true);
        if (this.parameters.seasonId == 0) {
            this.service
                .getVideosBySeries(this.parameters.seriesId, this.parameters.videosCount, this.isRandom, this.videoId)
                .subscribe((videos) => {
                const selectedIds = videos
                    .map(({ id }) => id)
                    .filter((x) => x.toString() != this.videosList[0].toString());
                this.videosList = this.videosList.concat(selectedIds);
            }, (err) => {
                console.log(`Cannot get video by series ${this.parameters.seriesId}`);
            });
        }
        else {
            this.service
                .getVideosBySeason(this.parameters.seasonId, this.parameters.videosCount, this.isRandom, this.videoId)
                .subscribe((videos) => {
                const selectedIds = videos
                    .map(({ id }) => id)
                    .filter((x) => x.toString() != this.videosList[0].toString());
                this.videosList = this.videosList.concat(selectedIds);
            }, (err) => {
                console.log(`Cannot get video by season ${this.parameters.seriesId}`);
            });
        }
        setTimeout(() => this.switchToFullscreen(), 2000);
        this.intervalId = setInterval(() => this.updateStat(), 1000);
    }
    getVideoElement() {
        if (this.video) {
            var videoEl = this.video.nativeElement;
            this.rewindNotificationValue = document.querySelector('.video-rewind-notify span');
            this.forwardNotificationValue = document.querySelector('.video-forward-notify span');
            this.notifications = document.querySelectorAll('.notification');
            let that = this;
            this.notifications.forEach(function (notification) {
                notification.addEventListener('animationend', (e) => that.animateNotificationOut(e));
            });
            // videoEl.addEventListener('dblclick', (e) => {
            //   e.preventDefault(); });
            return videoEl;
        }
    }
    startPlay() {
        let that = this;
        if (this.addMarkTimer)
            return;
        this.addMarkTimer = setTimeout(function () {
            let video = that.getVideoElement();
            if (video.paused === false)
                video.pause();
            else
                video.play();
            that.addMarkTimer = null;
        }, 300);
    }
    doubleClickHandler(e) {
        clearTimeout(this.addMarkTimer);
        this.addMarkTimer = null;
        e.preventDefault();
        const videoWidth = this.getVideoElement().offsetWidth;
        e.offsetX < videoWidth / 2 ? this.rewindVideo() : this.forwardVideo();
    }
    forwardVideo() {
        this.updateCurrentTime(10);
        this.animateNotificationIn(false);
    }
    rewindVideo() {
        this.updateCurrentTime(-10);
        this.animateNotificationIn(true);
    }
    moveToGood() {
        this.moveToSeries(14);
    }
    moveToBad() {
        this.moveToSeries(6107);
    }
    moveToSeries(serieId) {
        this.service.setSeriesId(serieId, this.videoId).subscribe();
    }
    showMoveModal() {
        const dialog = document.getElementById('moveDialog');
        dialog.showModal();
    }
    moveFilm(toBad) {
        const dialog = document.getElementById('moveDialog');
        dialog.close();
        if (toBad) {
            this.moveToBad();
        }
        else
            this.moveToGood();
    }
    animateNotificationOut(event) {
        this.notifications.forEach((x) => x.classList.remove('animate-in'));
    }
    updateCurrentTime(delta) {
        let isRewinding = delta < 0;
        if (isRewinding) {
            this.rewindSpeed = this.rewindSpeed + delta;
            this.forwardSpeed = 0;
        }
        else {
            this.forwardSpeed = this.forwardSpeed + delta;
            this.rewindSpeed = 0;
        }
        //clear the timeout
        clearTimeout(this.timer);
        let speed = isRewinding ? this.rewindSpeed : this.forwardSpeed;
        this.getVideoElement().currentTime =
            this.getVideoElement().currentTime + speed;
        let NotificationValue = isRewinding
            ? this.rewindNotificationValue
            : this.forwardNotificationValue;
        NotificationValue.innerHTML = `${Math.abs(speed)} seconds`;
        //reset accumulator within 2 seconds of a double click
        this.timer = setTimeout(function () {
            this.rewindSpeed = 0;
            this.forwardSpeed = 0;
        }, 2000); // you can edit this delay value for the timeout, i have it set for 2 seconds
    }
    animateNotificationIn(isRewinding) {
        isRewinding
            ? this.notifications[0].classList.add('animate-in')
            : this.notifications[1].classList.add('animate-in');
    }
    showDeleteModal() {
        const dialog = document.getElementById('favDialog');
        dialog.showModal();
    }
    deleteFilm(deleteFilm) {
        const dialog = document.getElementById('favDialog');
        dialog.close();
        if (deleteFilm) {
            this.location.back();
            this.service.deleteBook(this.videoId).subscribe();
        }
    }
    videoEnded() {
        console.log('ended');
        if (this.setNextVideo(true))
            this.getVideoElement().load();
        // TODO - show end show screen
    }
    seeking(ev) {
        console.log(ev);
        var video = this.getVideoElement();
        this.seekPositions.TryAddPosition(this.lastPosition, video.currentTime);
    }
    download() {
        window.open(this.videoURL, '_blank');
    }
    copyLink() {
        this.copyToClipboard(this.videoURL);
        // navigator.clipboard.writeText(this.videoURL).then().catch(e => console.error(e));
    }
    copyToClipboard(text) {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(text);
        }
        else {
            alert(text);
        }
    }
    skipVideo() {
        this.service.setRating(this.videoId, -1).subscribe();
        this.getVideoElement().pause();
        this.getVideoElement().currentTime = 0;
        this.videoURL = '';
        this.getVideoElement().load();
        if (this.setNextVideo(false))
            this.getVideoElement().load();
        // this.getVideoElement().play();
        // this.updateStat();
    }
    setTimer() {
        if (this.interval)
            clearInterval(this.interval);
        this.timeLeft = this.timerMinutes * 60;
        this.interval = Number(setInterval(() => {
            if (this.timeLeft > 0) {
                this.timeLeft--;
            }
            else
                this.setNextVideo(true);
        }, 1000));
    }
    switchToFullscreen() {
        var el = this.getVideoElement();
        if (el && el.requestFullscreen)
            el.requestFullscreen();
    }
    setNextVideo(encreaseCounter) {
        console.log(`Video ended ${this.videoURL} ${this.name}`);
        if (this.parameters.videosCount <= this.playedVideoCount) {
            this.videoURL = null;
            if (this.parameters.showDeleteButton == true)
                this.showDeleteModal();
            else if (this.isSovietAnimation)
                this.showMoveModal();
            return false;
        }
        let currentId = this.videosList[++this.currentVideoIndex];
        this.videoId = currentId;
        this.videoURL = this.service.getVideoURLById(currentId);
        //this.download();
        this.vlcPlayURL = `vlc://${this.videoURL}`;
        var el = this.getVideoElement();
        el === null || el === void 0 ? void 0 : el.load();
        if (encreaseCounter) {
            this.playedVideoCount++;
            var video = this.getVideoElement();
            if (video)
                this.previousVideoTimePlayed = this.totalDuration.clone();
        }
        this.service.getBookById(currentId).subscribe((videoInfo) => {
            this.name = videoInfo.displayName;
            this.videoInfo = videoInfo;
            // this.setPosition(videoInfo.currentPosition);
        }, (err) => {
            console.log(`Cannot get video by series ${this.parameters.seriesId}`);
        });
        return true;
    }
    updateStat() {
        var video = this.getVideoElement();
        if (!video || video.paused)
            return;
        this.setPosition();
        this.totalDuration = moment__WEBPACK_IMPORTED_MODULE_0__(this.previousVideoTimePlayed);
        if (video) {
            this.totalDuration = this.totalDuration.add(video.currentTime, 'seconds');
            if (video.currentTime > 10) {
                this.lastPosition = video.currentTime;
                this.service.setPosition(this.videoId, video.currentTime);
            }
        }
        if (this.totalDuration.seconds() - video.currentTime > 2)
            this.statStr = `Общее время просмотра всех серий ${this.totalDuration.format('mm:ss')} ${this.playedVideoCount}/${this.parameters.videosCount}`;
    }
    setPosition() {
        if (!this.videoInfo)
            return;
        const position = this.videoInfo.currentPosition;
        var video = this.getVideoElement();
        if (video.duration && position > 0 && video) {
            if (Math.abs(video.duration - position) < 30) {
                video.pause();
            }
            video.currentTime = position;
            this.videoInfo = null;
        }
    }
}
PlayerComponent.ɵfac = function PlayerComponent_Factory(t) { return new (t || PlayerComponent)(_angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵdirectiveInject"](src_app_services_file_service__WEBPACK_IMPORTED_MODULE_3__.FileService), _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵdirectiveInject"](src_app_services_series_service__WEBPACK_IMPORTED_MODULE_4__.SeriesService), _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵdirectiveInject"](_angular_router__WEBPACK_IMPORTED_MODULE_9__.Router), _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵdirectiveInject"](_angular_common__WEBPACK_IMPORTED_MODULE_10__.Location), _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵdirectiveInject"](_angular_router__WEBPACK_IMPORTED_MODULE_9__.ActivatedRoute), _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵdirectiveInject"](ngx_toastr__WEBPACK_IMPORTED_MODULE_11__.ToastrService)); };
PlayerComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵdefineComponent"]({ type: PlayerComponent, selectors: [["app-player"]], viewQuery: function PlayerComponent_Query(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵviewQuery"](_c0, 5);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵviewQuery"](_c1, 5);
    } if (rf & 2) {
        let _t;
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵqueryRefresh"](_t = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵloadQuery"]()) && (ctx.video = _t.first);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵqueryRefresh"](_t = _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵloadQuery"]()) && (ctx.child = _t.first);
    } }, decls: 20, vars: 2, consts: [["id", "favDialog"], [1, "mt-2", 2, "text-align", "center"], [1, "btn", "btn-outline-warning", 3, "click"], [1, "btn", "btn-outline-danger", "ml-5", 3, "click"], ["id", "moveDialog"], [1, "btn", "btn-outline-warning", "btn-sm", "ml-2", 3, "click"], [1, "btn", "btn-outline-success", "btn-sm", "ml-2", 3, "click"], ["class", "bg", "alt", "Finish!", "src", "./assets/img/finish.jpg", 4, "ngIf"], ["class", "video-container", 4, "ngIf"], ["alt", "Finish!", "src", "./assets/img/finish.jpg", 1, "bg"], [1, "video-container"], ["controls", "", "height", "auto", "autoplay", "", "class", "player__video viewer", "controlsList", "nofullscreen", "id", "player", 3, "dblclick", "click", "ended", "seeked", 4, "ngIf"], ["controls", "", "height", "auto", "autoplay", "", "class", "player__video viewer", "id", "player", 3, "ended", "seeked", 4, "ngIf"], [1, "video-rewind-notify", "rewind", "notification"], [1, "rewind-icon", "icon"], [1, "left-triangle", "triangle"], [1, "rewind"], [1, "video-forward-notify", "forward", "notification"], [1, "forward-icon", "icon"], [1, "right-triangle", "triangle"], [1, "forward"], [1, "ml-2"], [1, "btn", "btn-outline-danger", "btn-sm", 3, "click"], [3, "href"], [1, "btn", "btn-outline-warning", "btn-sm", "ml-2"], ["mat-icon-button", "", "color", "primary", "data-toggle", "tooltip", "data-placement", "top", "title", "\u0421\u043A\u043E\u043F\u0438\u0440\u043E\u0432\u0430\u0442\u044C \u0441\u0441\u044B\u043B\u043A\u0443"], [3, "click"], ["mat-icon-button", "", "color", "warn", 3, "click", 4, "ngIf"], ["mat-icon-button", "", "color", "accent", 3, "click"], ["href", "#"], ["mat-icon-button", ""], [4, "ngIf"], [3, "videoId"], ["markslist", ""], [3, "positions"], ["positionslist", ""], ["appearance", "fill", 1, "example-full-width"], ["matInput", "", "type", "number", 3, "ngModel", "ngModelChange", "keyup.enter"], ["mat-icon-button", "", "color", "primary", 3, "click"], ["controls", "", "height", "auto", "autoplay", "", "controlsList", "nofullscreen", "id", "player", 1, "player__video", "viewer", 3, "dblclick", "click", "ended", "seeked"], ["videoElement", ""], ["type", "video/mp4", 3, "src"], ["controls", "", "height", "auto", "autoplay", "", "id", "player", 1, "player__video", "viewer", 3, "ended", "seeked"], ["mat-icon-button", "", "color", "warn", 3, "click"]], template: function PlayerComponent_Template(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](0, "dialog", 0);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](1, "div");
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](2, "\u0412\u044B \u0443\u0432\u0435\u0440\u0435\u043D\u044B, \u0447\u0442\u043E \u0445\u043E\u0442\u0438\u0442\u0435 \u0443\u0434\u0430\u043B\u0438\u0442\u044C \u0444\u0438\u043B\u044C\u043C?");
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](3, "div", 1);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](4, "button", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_Template_button_click_4_listener() { return ctx.deleteFilm(false); });
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](5, " \u041D\u0435\u0442 ");
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](6, "button", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_Template_button_click_6_listener() { return ctx.deleteFilm(true); });
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](7, " \u0414\u0430 ");
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](8, "dialog", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](9, "div");
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](10, "\u041F\u0435\u0440\u0435\u043C\u0435\u0441\u0442\u0438\u0442\u044C \u0444\u0438\u043B\u044C\u043C?");
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](11, "div", 1);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](12, "button", 5);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_Template_button_click_12_listener() { return ctx.moveFilm(true); });
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](13, " \u0412 \u043F\u043B\u043E\u0445\u0438\u0435 ");
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](14, "button", 6);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵlistener"]("click", function PlayerComponent_Template_button_click_14_listener() { return ctx.moveFilm(false); });
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtext"](15, " \u0412 \u0445\u043E\u0440\u043E\u0448\u0438\u0435 ");
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](16, "div");
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementStart"](17, "div");
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtemplate"](18, PlayerComponent_img_18_Template, 1, 0, "img", 7);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵtemplate"](19, PlayerComponent_div_19_Template, 60, 13, "div", 8);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵelementEnd"]();
    } if (rf & 2) {
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](18);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("ngIf", !ctx.videoURL);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_8__["ɵɵproperty"]("ngIf", ctx.videoURL);
    } }, directives: [_angular_common__WEBPACK_IMPORTED_MODULE_10__.NgIf, _angular_material_button__WEBPACK_IMPORTED_MODULE_12__.MatButton, _angular_material_icon__WEBPACK_IMPORTED_MODULE_13__.MatIcon, _markslist_markslist_component__WEBPACK_IMPORTED_MODULE_5__.MarkslistComponent, _positionslist_positionslist_component__WEBPACK_IMPORTED_MODULE_6__.PositionslistComponent, _angular_material_form_field__WEBPACK_IMPORTED_MODULE_14__.MatFormField, _angular_material_form_field__WEBPACK_IMPORTED_MODULE_14__.MatLabel, _angular_material_input__WEBPACK_IMPORTED_MODULE_15__.MatInput, _angular_forms__WEBPACK_IMPORTED_MODULE_16__.NumberValueAccessor, _angular_forms__WEBPACK_IMPORTED_MODULE_16__.DefaultValueAccessor, _angular_forms__WEBPACK_IMPORTED_MODULE_16__.NgControlStatus, _angular_forms__WEBPACK_IMPORTED_MODULE_16__.NgModel], pipes: [_services_SafePipe__WEBPACK_IMPORTED_MODULE_7__.SafePipe, _angular_common__WEBPACK_IMPORTED_MODULE_10__.DatePipe], styles: [".form[_ngcontent-%COMP%] {\r\n    margin: 0 auto !important;\r\n    float: none !important;\r\n}\r\n\r\nvideo[_ngcontent-%COMP%]{\r\n    width: 100%;\r\n    cursor: pointer;\r\n    display:block;\r\n}\r\n\r\na[_ngcontent-%COMP%]{\r\n    color: rgb(0, 123, 255) !important;\r\n    -webkit-text-decoration-style: solid;\r\n            text-decoration-style: solid;\r\n    cursor:pointer ;\r\n}\r\n\r\n.video-forward-notify[_ngcontent-%COMP%]{\r\n  text-align: center;\r\n  width:100%;\r\n  height:200%;\r\n  border-radius:100% 0 0 100%;\r\n  position: absolute;\r\n  display:flex;\r\n  flex-direction: row;\r\n  right: -50%;\r\n  top:-50%;\r\n}\r\n\r\n.video-forward-notify[_ngcontent-%COMP%]   .icon[_ngcontent-%COMP%]{\r\n  justify-content:flex-start;\r\n  align-items:center;\r\n  margin: auto 0 auto 15%;\r\n  color: rgba(255,255,255, 1);\r\n}\r\n\r\n.video-rewind-notify[_ngcontent-%COMP%]{\r\n  text-align: center;\r\n  width:100%;\r\n  height:200%;\r\n  border-radius:0 100% 100% 0;\r\n  position: absolute;\r\n  display:flex;\r\n  flex-direction: row;\r\n  left: -50%;\r\n  top:-50%;\r\n}\r\n\r\n.video-rewind-notify[_ngcontent-%COMP%]   .icon[_ngcontent-%COMP%]{\r\n  justify-content:flex-start;\r\n  align-items:center;\r\n  margin: auto 0 auto 60%;\r\n  color: rgba(255,255,255, 1);\r\n}\r\n\r\n.icon[_ngcontent-%COMP%]   i[_ngcontent-%COMP%]{\r\n  display:block;\r\n}\r\n\r\n.notification[_ngcontent-%COMP%]{\r\n  transition: background 0.8s;\r\n  background: rgba(200,200,200,.4) radial-gradient(circle, transparent 1%, rgba(200,200,200,.4) 1%) center/15000%;\r\n  pointer-events:none;\r\n  display: none;\r\n}\r\n\r\ni[_ngcontent-%COMP%]{\r\n  font-style:normal;\r\n}\r\n\r\n.animate-in[_ngcontent-%COMP%]{\r\n  display:flex;\r\n  -webkit-animation: ripple 1s forwards;\r\n          animation: ripple 1s forwards;\r\n}\r\n\r\n.animate-in[_ngcontent-%COMP%]   i[_ngcontent-%COMP%]{\r\n  display:block;\r\n}\r\n\r\n.animate-in.forward[_ngcontent-%COMP%]   i[_ngcontent-%COMP%]{\r\n  padding-bottom:2px;\r\n}\r\n\r\n.animate-in.forward[_ngcontent-%COMP%]   i[_ngcontent-%COMP%]{\r\n  -webkit-animation: fadeInLeft .7s;\r\n          animation: fadeInLeft .7s;\r\n}\r\n\r\n.animate-in.rewind[_ngcontent-%COMP%]   i[_ngcontent-%COMP%]{\r\n  -webkit-animation: fadeInRight .7s;\r\n          animation: fadeInRight .7s;\r\n}\r\n\r\n@-webkit-keyframes ripple{\r\n  0%   {\r\n    background-color: rgba(200,200,200,.4);\r\n    background-size: 100%;\r\n    transition: background 0s;\r\n    opacity:1;\r\n  }\r\n  100% {\r\n  transition: background 0.8s;\r\n  background: rgba(200,200,200,.4) radial-gradient(circle, transparent 1%, rgba(200,200,200,.4) 1%) center/15000%;\r\n  display: flex;\r\n    opacity:0;\r\n  }\r\n}\r\n\r\n@keyframes ripple{\r\n  0%   {\r\n    background-color: rgba(200,200,200,.4);\r\n    background-size: 100%;\r\n    transition: background 0s;\r\n    opacity:1;\r\n  }\r\n  100% {\r\n  transition: background 0.8s;\r\n  background: rgba(200,200,200,.4) radial-gradient(circle, transparent 1%, rgba(200,200,200,.4) 1%) center/15000%;\r\n  display: flex;\r\n    opacity:0;\r\n  }\r\n}\r\n\r\n@-webkit-keyframes fadeInLeft {\r\n  0% {\r\n    opacity: 0;\r\n    transform: translateX(-20px);\r\n  }\r\n  100% {\r\n    opacity: 1;\r\n    transform: translateX(0);\r\n  }\r\n}\r\n\r\n@keyframes fadeInLeft {\r\n  0% {\r\n    opacity: 0;\r\n    transform: translateX(-20px);\r\n  }\r\n  100% {\r\n    opacity: 1;\r\n    transform: translateX(0);\r\n  }\r\n}\r\n\r\n@-webkit-keyframes fadeInRight {\r\n  0% {\r\n    opacity: 0;\r\n    transform: translateX(0px);\r\n  }\r\n  100% {\r\n    opacity: 1;\r\n    transform: translateX(-20px);\r\n  }\r\n}\r\n\r\n@keyframes fadeInRight {\r\n  0% {\r\n    opacity: 0;\r\n    transform: translateX(0px);\r\n  }\r\n  100% {\r\n    opacity: 1;\r\n    transform: translateX(-20px);\r\n  }\r\n}\r\n\r\nspan[_ngcontent-%COMP%]{\r\n  font-size:12px;\r\n}\r\n\r\nbody[_ngcontent-%COMP%] {\r\n  margin: 0;\r\n  padding: 0;\r\n  display: flex;\r\n  background: #7A419B;\r\n  min-height: 100vh;\r\n  background: #fff;\r\n  background-size: cover;\r\n  align-items: center;\r\n  justify-content: center;\r\n}\r\n\r\nhtml[_ngcontent-%COMP%] {\r\n  box-sizing: border-box;\r\n  font-family: 'Helvetica';\r\n}\r\n\r\n*[_ngcontent-%COMP%], *[_ngcontent-%COMP%]:before, *[_ngcontent-%COMP%]:after {\r\n  box-sizing: inherit;\r\n}\r\n\r\nimg.bg[_ngcontent-%COMP%] {\r\n  \r\n  min-height: 100%;\r\n  min-width: 1024px;\r\n\r\n  \r\n  width: 100%;\r\n  height: auto;\r\n\r\n  \r\n  position: fixed;\r\n  top: 0;\r\n  left: 0;\r\n}\r\n\r\n@media screen and (max-width: 1024px) { \r\n  img.bg[_ngcontent-%COMP%] {\r\n    left: 50%;\r\n    margin-left: -512px;   \r\n  }\r\n}\r\n\r\nbutton[mat-icon-button][_ngcontent-%COMP%] {\r\n  transform: scale(1.5);\r\n}\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbInBsYXllci5jb21wb25lbnQuY3NzIl0sIm5hbWVzIjpbXSwibWFwcGluZ3MiOiJBQUFBO0lBQ0kseUJBQXlCO0lBQ3pCLHNCQUFzQjtBQUMxQjs7QUFFQTtJQUNJLFdBQVc7SUFDWCxlQUFlO0lBQ2YsYUFBYTtBQUNqQjs7QUFFQTtJQUNJLGtDQUFrQztJQUNsQyxvQ0FBNEI7WUFBNUIsNEJBQTRCO0lBQzVCLGVBQWU7QUFDbkI7O0FBR0E7RUFDRSxrQkFBa0I7RUFDbEIsVUFBVTtFQUNWLFdBQVc7RUFDWCwyQkFBMkI7RUFDM0Isa0JBQWtCO0VBQ2xCLFlBQVk7RUFDWixtQkFBbUI7RUFDbkIsV0FBVztFQUNYLFFBQVE7QUFDVjs7QUFFQTtFQUNFLDBCQUEwQjtFQUMxQixrQkFBa0I7RUFDbEIsdUJBQXVCO0VBQ3ZCLDJCQUEyQjtBQUM3Qjs7QUFDQTtFQUNFLGtCQUFrQjtFQUNsQixVQUFVO0VBQ1YsV0FBVztFQUNYLDJCQUEyQjtFQUMzQixrQkFBa0I7RUFDbEIsWUFBWTtFQUNaLG1CQUFtQjtFQUNuQixVQUFVO0VBQ1YsUUFBUTtBQUNWOztBQUVBO0VBQ0UsMEJBQTBCO0VBQzFCLGtCQUFrQjtFQUNsQix1QkFBdUI7RUFDdkIsMkJBQTJCO0FBQzdCOztBQUNBO0VBQ0UsYUFBYTtBQUNmOztBQUNBO0VBQ0UsMkJBQTJCO0VBQzNCLCtHQUErRztFQUMvRyxtQkFBbUI7RUFDbkIsYUFBYTtBQUNmOztBQUNBO0VBQ0UsaUJBQWlCO0FBQ25COztBQUNBO0VBQ0UsWUFBWTtFQUNaLHFDQUE2QjtVQUE3Qiw2QkFBNkI7QUFDL0I7O0FBQ0E7RUFDRSxhQUFhO0FBQ2Y7O0FBQ0E7RUFDRSxrQkFBa0I7QUFDcEI7O0FBQ0E7RUFDRSxpQ0FBeUI7VUFBekIseUJBQXlCO0FBQzNCOztBQUNBO0VBQ0Usa0NBQTBCO1VBQTFCLDBCQUEwQjtBQUM1Qjs7QUFDQTtFQUNFO0lBQ0Usc0NBQXNDO0lBQ3RDLHFCQUFxQjtJQUNyQix5QkFBeUI7SUFDekIsU0FBUztFQUNYO0VBQ0E7RUFDQSwyQkFBMkI7RUFDM0IsK0dBQStHO0VBQy9HLGFBQWE7SUFDWCxTQUFTO0VBQ1g7QUFDRjs7QUFiQTtFQUNFO0lBQ0Usc0NBQXNDO0lBQ3RDLHFCQUFxQjtJQUNyQix5QkFBeUI7SUFDekIsU0FBUztFQUNYO0VBQ0E7RUFDQSwyQkFBMkI7RUFDM0IsK0dBQStHO0VBQy9HLGFBQWE7SUFDWCxTQUFTO0VBQ1g7QUFDRjs7QUFDQTtFQUNFO0lBQ0UsVUFBVTtJQUNWLDRCQUE0QjtFQUM5QjtFQUNBO0lBQ0UsVUFBVTtJQUNWLHdCQUF3QjtFQUMxQjtBQUNGOztBQVRBO0VBQ0U7SUFDRSxVQUFVO0lBQ1YsNEJBQTRCO0VBQzlCO0VBQ0E7SUFDRSxVQUFVO0lBQ1Ysd0JBQXdCO0VBQzFCO0FBQ0Y7O0FBQ0E7RUFDRTtJQUNFLFVBQVU7SUFDViwwQkFBMEI7RUFDNUI7RUFDQTtJQUNFLFVBQVU7SUFDViw0QkFBNEI7RUFDOUI7QUFDRjs7QUFUQTtFQUNFO0lBQ0UsVUFBVTtJQUNWLDBCQUEwQjtFQUM1QjtFQUNBO0lBQ0UsVUFBVTtJQUNWLDRCQUE0QjtFQUM5QjtBQUNGOztBQUNBO0VBQ0UsY0FBYztBQUNoQjs7QUFFQTtFQUNFLFNBQVM7RUFDVCxVQUFVO0VBQ1YsYUFBYTtFQUNiLG1CQUFtQjtFQUNuQixpQkFBaUI7RUFDakIsZ0JBQWdCO0VBQ2hCLHNCQUFzQjtFQUN0QixtQkFBbUI7RUFDbkIsdUJBQXVCO0FBQ3pCOztBQUNBO0VBQ0Usc0JBQXNCO0VBQ3RCLHdCQUF3QjtBQUMxQjs7QUFFQTtFQUNFLG1CQUFtQjtBQUNyQjs7QUFFQTtFQUNFLGlDQUFpQztFQUNqQyxnQkFBZ0I7RUFDaEIsaUJBQWlCOztFQUVqQixpQ0FBaUM7RUFDakMsV0FBVztFQUNYLFlBQVk7O0VBRVosdUJBQXVCO0VBQ3ZCLGVBQWU7RUFDZixNQUFNO0VBQ04sT0FBTztBQUNUOztBQUVBLHdDQUF3QyxzQ0FBc0M7RUFDNUU7SUFDRSxTQUFTO0lBQ1QsbUJBQW1CLElBQUksUUFBUTtFQUNqQztBQUNGOztBQUVBO0VBQ0UscUJBQXFCO0FBQ3ZCIiwiZmlsZSI6InBsYXllci5jb21wb25lbnQuY3NzIiwic291cmNlc0NvbnRlbnQiOlsiLmZvcm0ge1xyXG4gICAgbWFyZ2luOiAwIGF1dG8gIWltcG9ydGFudDtcclxuICAgIGZsb2F0OiBub25lICFpbXBvcnRhbnQ7XHJcbn1cclxuXHJcbnZpZGVve1xyXG4gICAgd2lkdGg6IDEwMCU7XHJcbiAgICBjdXJzb3I6IHBvaW50ZXI7XHJcbiAgICBkaXNwbGF5OmJsb2NrO1xyXG59XHJcblxyXG5he1xyXG4gICAgY29sb3I6IHJnYigwLCAxMjMsIDI1NSkgIWltcG9ydGFudDtcclxuICAgIHRleHQtZGVjb3JhdGlvbi1zdHlsZTogc29saWQ7XHJcbiAgICBjdXJzb3I6cG9pbnRlciA7XHJcbn1cclxuXHJcblxyXG4udmlkZW8tZm9yd2FyZC1ub3RpZnl7XHJcbiAgdGV4dC1hbGlnbjogY2VudGVyO1xyXG4gIHdpZHRoOjEwMCU7XHJcbiAgaGVpZ2h0OjIwMCU7XHJcbiAgYm9yZGVyLXJhZGl1czoxMDAlIDAgMCAxMDAlO1xyXG4gIHBvc2l0aW9uOiBhYnNvbHV0ZTtcclxuICBkaXNwbGF5OmZsZXg7XHJcbiAgZmxleC1kaXJlY3Rpb246IHJvdztcclxuICByaWdodDogLTUwJTtcclxuICB0b3A6LTUwJTtcclxufVxyXG5cclxuLnZpZGVvLWZvcndhcmQtbm90aWZ5IC5pY29ue1xyXG4gIGp1c3RpZnktY29udGVudDpmbGV4LXN0YXJ0O1xyXG4gIGFsaWduLWl0ZW1zOmNlbnRlcjtcclxuICBtYXJnaW46IGF1dG8gMCBhdXRvIDE1JTtcclxuICBjb2xvcjogcmdiYSgyNTUsMjU1LDI1NSwgMSk7XHJcbn1cclxuLnZpZGVvLXJld2luZC1ub3RpZnl7XHJcbiAgdGV4dC1hbGlnbjogY2VudGVyO1xyXG4gIHdpZHRoOjEwMCU7XHJcbiAgaGVpZ2h0OjIwMCU7XHJcbiAgYm9yZGVyLXJhZGl1czowIDEwMCUgMTAwJSAwO1xyXG4gIHBvc2l0aW9uOiBhYnNvbHV0ZTtcclxuICBkaXNwbGF5OmZsZXg7XHJcbiAgZmxleC1kaXJlY3Rpb246IHJvdztcclxuICBsZWZ0OiAtNTAlO1xyXG4gIHRvcDotNTAlO1xyXG59XHJcblxyXG4udmlkZW8tcmV3aW5kLW5vdGlmeSAuaWNvbntcclxuICBqdXN0aWZ5LWNvbnRlbnQ6ZmxleC1zdGFydDtcclxuICBhbGlnbi1pdGVtczpjZW50ZXI7XHJcbiAgbWFyZ2luOiBhdXRvIDAgYXV0byA2MCU7XHJcbiAgY29sb3I6IHJnYmEoMjU1LDI1NSwyNTUsIDEpO1xyXG59XHJcbi5pY29uIGl7XHJcbiAgZGlzcGxheTpibG9jaztcclxufVxyXG4ubm90aWZpY2F0aW9ue1xyXG4gIHRyYW5zaXRpb246IGJhY2tncm91bmQgMC44cztcclxuICBiYWNrZ3JvdW5kOiByZ2JhKDIwMCwyMDAsMjAwLC40KSByYWRpYWwtZ3JhZGllbnQoY2lyY2xlLCB0cmFuc3BhcmVudCAxJSwgcmdiYSgyMDAsMjAwLDIwMCwuNCkgMSUpIGNlbnRlci8xNTAwMCU7XHJcbiAgcG9pbnRlci1ldmVudHM6bm9uZTtcclxuICBkaXNwbGF5OiBub25lO1xyXG59XHJcbml7XHJcbiAgZm9udC1zdHlsZTpub3JtYWw7XHJcbn1cclxuLmFuaW1hdGUtaW57XHJcbiAgZGlzcGxheTpmbGV4O1xyXG4gIGFuaW1hdGlvbjogcmlwcGxlIDFzIGZvcndhcmRzO1xyXG59XHJcbi5hbmltYXRlLWluIGl7XHJcbiAgZGlzcGxheTpibG9jaztcclxufVxyXG4uYW5pbWF0ZS1pbi5mb3J3YXJkIGl7XHJcbiAgcGFkZGluZy1ib3R0b206MnB4O1xyXG59XHJcbi5hbmltYXRlLWluLmZvcndhcmQgaXtcclxuICBhbmltYXRpb246IGZhZGVJbkxlZnQgLjdzO1xyXG59XHJcbi5hbmltYXRlLWluLnJld2luZCBpe1xyXG4gIGFuaW1hdGlvbjogZmFkZUluUmlnaHQgLjdzO1xyXG59XHJcbkBrZXlmcmFtZXMgcmlwcGxle1xyXG4gIDAlICAge1xyXG4gICAgYmFja2dyb3VuZC1jb2xvcjogcmdiYSgyMDAsMjAwLDIwMCwuNCk7XHJcbiAgICBiYWNrZ3JvdW5kLXNpemU6IDEwMCU7XHJcbiAgICB0cmFuc2l0aW9uOiBiYWNrZ3JvdW5kIDBzO1xyXG4gICAgb3BhY2l0eToxO1xyXG4gIH1cclxuICAxMDAlIHtcclxuICB0cmFuc2l0aW9uOiBiYWNrZ3JvdW5kIDAuOHM7XHJcbiAgYmFja2dyb3VuZDogcmdiYSgyMDAsMjAwLDIwMCwuNCkgcmFkaWFsLWdyYWRpZW50KGNpcmNsZSwgdHJhbnNwYXJlbnQgMSUsIHJnYmEoMjAwLDIwMCwyMDAsLjQpIDElKSBjZW50ZXIvMTUwMDAlO1xyXG4gIGRpc3BsYXk6IGZsZXg7XHJcbiAgICBvcGFjaXR5OjA7XHJcbiAgfVxyXG59XHJcbkBrZXlmcmFtZXMgZmFkZUluTGVmdCB7XHJcbiAgMCUge1xyXG4gICAgb3BhY2l0eTogMDtcclxuICAgIHRyYW5zZm9ybTogdHJhbnNsYXRlWCgtMjBweCk7XHJcbiAgfVxyXG4gIDEwMCUge1xyXG4gICAgb3BhY2l0eTogMTtcclxuICAgIHRyYW5zZm9ybTogdHJhbnNsYXRlWCgwKTtcclxuICB9XHJcbn1cclxuQGtleWZyYW1lcyBmYWRlSW5SaWdodCB7XHJcbiAgMCUge1xyXG4gICAgb3BhY2l0eTogMDtcclxuICAgIHRyYW5zZm9ybTogdHJhbnNsYXRlWCgwcHgpO1xyXG4gIH1cclxuICAxMDAlIHtcclxuICAgIG9wYWNpdHk6IDE7XHJcbiAgICB0cmFuc2Zvcm06IHRyYW5zbGF0ZVgoLTIwcHgpO1xyXG4gIH1cclxufVxyXG5zcGFue1xyXG4gIGZvbnQtc2l6ZToxMnB4O1xyXG59XHJcblxyXG5ib2R5IHtcclxuICBtYXJnaW46IDA7XHJcbiAgcGFkZGluZzogMDtcclxuICBkaXNwbGF5OiBmbGV4O1xyXG4gIGJhY2tncm91bmQ6ICM3QTQxOUI7XHJcbiAgbWluLWhlaWdodDogMTAwdmg7XHJcbiAgYmFja2dyb3VuZDogI2ZmZjtcclxuICBiYWNrZ3JvdW5kLXNpemU6IGNvdmVyO1xyXG4gIGFsaWduLWl0ZW1zOiBjZW50ZXI7XHJcbiAganVzdGlmeS1jb250ZW50OiBjZW50ZXI7XHJcbn1cclxuaHRtbCB7XHJcbiAgYm94LXNpemluZzogYm9yZGVyLWJveDtcclxuICBmb250LWZhbWlseTogJ0hlbHZldGljYSc7XHJcbn1cclxuXHJcbiosICo6YmVmb3JlLCAqOmFmdGVyIHtcclxuICBib3gtc2l6aW5nOiBpbmhlcml0O1xyXG59XHJcblxyXG5pbWcuYmcge1xyXG4gIC8qIFNldCBydWxlcyB0byBmaWxsIGJhY2tncm91bmQgKi9cclxuICBtaW4taGVpZ2h0OiAxMDAlO1xyXG4gIG1pbi13aWR0aDogMTAyNHB4O1xyXG5cclxuICAvKiBTZXQgdXAgcHJvcG9ydGlvbmF0ZSBzY2FsaW5nICovXHJcbiAgd2lkdGg6IDEwMCU7XHJcbiAgaGVpZ2h0OiBhdXRvO1xyXG5cclxuICAvKiBTZXQgdXAgcG9zaXRpb25pbmcgKi9cclxuICBwb3NpdGlvbjogZml4ZWQ7XHJcbiAgdG9wOiAwO1xyXG4gIGxlZnQ6IDA7XHJcbn1cclxuXHJcbkBtZWRpYSBzY3JlZW4gYW5kIChtYXgtd2lkdGg6IDEwMjRweCkgeyAvKiBTcGVjaWZpYyB0byB0aGlzIHBhcnRpY3VsYXIgaW1hZ2UgKi9cclxuICBpbWcuYmcge1xyXG4gICAgbGVmdDogNTAlO1xyXG4gICAgbWFyZ2luLWxlZnQ6IC01MTJweDsgICAvKiA1MCUgKi9cclxuICB9XHJcbn1cclxuXHJcbmJ1dHRvblttYXQtaWNvbi1idXR0b25dIHtcclxuICB0cmFuc2Zvcm06IHNjYWxlKDEuNSk7XHJcbn1cclxuIl19 */"] });


/***/ }),

/***/ 1639:
/*!*********************************************************************!*\
  !*** ./src/app/categories/category-list/category-list.component.ts ***!
  \*********************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "CategoryListComponent": () => (/* binding */ CategoryListComponent)
/* harmony export */ });
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! rxjs */ 2218);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! rxjs/operators */ 823);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! @angular/router */ 2816);
/* harmony import */ var src_app_services_series_service__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! src/app/_services/series.service */ 8422);
/* harmony import */ var ngx_toastr__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ngx-toastr */ 2808);
/* harmony import */ var src_app_services_confirmation_dialog_service__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! src/app/_services/confirmation-dialog.service */ 9696);
/* harmony import */ var _angular_forms__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! @angular/forms */ 587);
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! @angular/common */ 6362);









function CategoryListComponent_tr_23_Template(rf, ctx) { if (rf & 1) {
    const _r3 = _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](0, "tr");
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](1, "td");
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵtext"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](3, "td", 14);
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](4, "a", 15);
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵlistener"]("click", function CategoryListComponent_tr_23_Template_a_click_4_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵrestoreView"](_r3); const category_r1 = restoredCtx.$implicit; const ctx_r2 = _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵnextContext"](); return ctx_r2.editCategory(category_r1.id); });
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelement"](5, "i", 16);
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](6, "a", 17);
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵlistener"]("click", function CategoryListComponent_tr_23_Template_a_click_6_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵrestoreView"](_r3); const category_r1 = restoredCtx.$implicit; const ctx_r4 = _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵnextContext"](); return ctx_r4.deleteCategory(category_r1.id); });
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelement"](7, "i", 18);
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
} if (rf & 2) {
    const category_r1 = ctx.$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵtextInterpolate"](category_r1.name);
} }
class CategoryListComponent {
    constructor(router, service, toastr, confirmationDialogService) {
        this.router = router;
        this.service = service;
        this.toastr = toastr;
        this.confirmationDialogService = confirmationDialogService;
        this.searchValueChanged = new rxjs__WEBPACK_IMPORTED_MODULE_3__.Subject();
    }
    ngOnInit() {
        this.getCategories();
        this.searchValueChanged.pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_4__.debounceTime)(1000))
            .subscribe(() => {
            this.search();
        });
    }
    getCategories() {
        this.service.getCategories().subscribe(categories => {
            this.categories = categories;
        });
    }
    addCategory() {
        this.router.navigate(['/category']);
    }
    editCategory(categoryId) {
        this.router.navigate(['/category/' + categoryId]);
    }
    deleteCategory(categoryId) {
        this.confirmationDialogService.confirm('Atention', 'Do you really want to delete this category?')
            .then(() => this.service.deleteCategory(categoryId).subscribe(() => {
            this.toastr.success('The category has been deleted');
            this.getCategories();
        }, error => {
            this.toastr.error('Failed to delete the category.');
        }))
            .catch(() => '');
    }
    searchCategories() {
        this.searchValueChanged.next();
    }
    search() {
        if (this.searchTerm !== '') {
            this.service.search(this.searchTerm).subscribe(category => {
                this.categories = category;
            }, error => {
                this.categories = [];
            });
        }
        else {
            this.service.getCategories().subscribe(categories => this.categories = categories);
        }
    }
}
CategoryListComponent.ɵfac = function CategoryListComponent_Factory(t) { return new (t || CategoryListComponent)(_angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵdirectiveInject"](_angular_router__WEBPACK_IMPORTED_MODULE_5__.Router), _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵdirectiveInject"](src_app_services_series_service__WEBPACK_IMPORTED_MODULE_0__.SeriesService), _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵdirectiveInject"](ngx_toastr__WEBPACK_IMPORTED_MODULE_6__.ToastrService), _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵdirectiveInject"](src_app_services_confirmation_dialog_service__WEBPACK_IMPORTED_MODULE_1__.ConfirmationDialogService)); };
CategoryListComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵdefineComponent"]({ type: CategoryListComponent, selectors: [["app-category-list"]], decls: 24, vars: 2, consts: [[1, "jumbtron"], [1, "display-4", "text-center"], [1, "col-md-12"], ["type", "button", 1, "btn", "btn-success", 3, "click"], [1, "form-group"], ["for", "Search"], [1, "input-group"], [1, "input-group-prepend"], [1, "input-group-text", "bg-white"], [1, "fas", "fa-search"], ["type", "text", 3, "ngModel", "ngModelChange"], [1, "table", "table-condensed", "table-bordered", "table-striped", "table-hover"], [1, "col-md-7"], [4, "ngFor", "ngForOf"], [1, "action-button-column"], ["title", "Edit", 3, "click"], [1, "fas", "fa-edit"], ["title", "Delete", 2, "margin-left", "12px", 3, "click"], [1, "fas", "fa-trash-alt"]], template: function CategoryListComponent_Template(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](0, "div", 0);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](1, "h1", 1);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵtext"](2, "Categories");
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](3, "div", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](4, "button", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵlistener"]("click", function CategoryListComponent_Template_button_click_4_listener() { return ctx.addCategory(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵtext"](5, "New Category");
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelement"](6, "hr");
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](7, "div", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](8, "label", 5);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵtext"](9, "Search");
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](10, "div", 6);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](11, "div", 7);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](12, "div", 8);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelement"](13, "i", 9);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](14, "input", 10);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵlistener"]("ngModelChange", function CategoryListComponent_Template_input_ngModelChange_14_listener($event) { return ctx.searchTerm = $event; })("ngModelChange", function CategoryListComponent_Template_input_ngModelChange_14_listener() { return ctx.searchCategories(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](15, "table", 11);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](16, "thead");
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](17, "tr");
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](18, "th", 12);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵtext"](19, "Category");
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](20, "th");
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵtext"](21, "Options");
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementStart"](22, "tbody");
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵtemplate"](23, CategoryListComponent_tr_23_Template, 8, 1, "tr", 13);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵelementEnd"]();
    } if (rf & 2) {
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵadvance"](14);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵproperty"]("ngModel", ctx.searchTerm);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵadvance"](9);
        _angular_core__WEBPACK_IMPORTED_MODULE_2__["ɵɵproperty"]("ngForOf", ctx.categories);
    } }, directives: [_angular_forms__WEBPACK_IMPORTED_MODULE_7__.DefaultValueAccessor, _angular_forms__WEBPACK_IMPORTED_MODULE_7__.NgControlStatus, _angular_forms__WEBPACK_IMPORTED_MODULE_7__.NgModel, _angular_common__WEBPACK_IMPORTED_MODULE_8__.NgForOf], styles: [".jumbtron[_ngcontent-%COMP%] {\n    padding-top: 60px;\n}\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbImNhdGVnb3J5LWxpc3QuY29tcG9uZW50LmNzcyJdLCJuYW1lcyI6W10sIm1hcHBpbmdzIjoiQUFBQTtJQUNJLGlCQUFpQjtBQUNyQiIsImZpbGUiOiJjYXRlZ29yeS1saXN0LmNvbXBvbmVudC5jc3MiLCJzb3VyY2VzQ29udGVudCI6WyIuanVtYnRyb24ge1xuICAgIHBhZGRpbmctdG9wOiA2MHB4O1xufVxuIl19 */"] });


/***/ }),

/***/ 5793:
/*!***********************************************************!*\
  !*** ./src/app/categories/category/category.component.ts ***!
  \***********************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "CategoryComponent": () => (/* binding */ CategoryComponent)
/* harmony export */ });
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var src_app_services_series_service__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! src/app/_services/series.service */ 8422);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @angular/router */ 2816);
/* harmony import */ var ngx_toastr__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ngx-toastr */ 2808);
/* harmony import */ var _angular_forms__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! @angular/forms */ 587);
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! @angular/common */ 6362);
/* harmony import */ var _angular_flex_layout_extended__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! @angular/flex-layout/extended */ 3338);







function CategoryComponent_div_10_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](0, "div", 13);
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](1, "Please inform the category.");
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
} }
const _c0 = function (a0) { return { "is-invalid": a0 }; };
class CategoryComponent {
    constructor(service, router, route, toastr) {
        this.service = service;
        this.router = router;
        this.route = route;
        this.toastr = toastr;
    }
    ngOnInit() {
        this.resetForm();
        let id;
        this.route.params.subscribe(params => {
            id = params['id'];
        });
        if (id != null) {
            this.service.getSerieById(id).subscribe(category => {
                this.formData = category;
            }, error => {
                this.toastr.error('An error occurred on get the record.');
            });
        }
        else {
            this.resetForm();
        }
    }
    resetForm(form) {
        if (form != null) {
            form.form.reset();
        }
        // this.formData = {
        //   id: 0,
        //   name: ''
        // };
    }
    onSubmit(form) {
        if (form.value.id === 0) {
            this.insertRecord(form);
        }
        else {
            this.updateRecord(form);
        }
    }
    insertRecord(form) {
        this.service.addCategory(form.form.value).subscribe(() => {
            this.toastr.success('Registration successful');
            this.resetForm(form);
            this.router.navigate(['/categories']);
        }, () => {
            this.toastr.error('An error occurred on insert the record.');
        });
    }
    updateRecord(form) {
        this.service.updateCategory(form.form.value.id, form.form.value).subscribe(() => {
            this.toastr.success('Updated successful');
            this.resetForm(form);
            this.router.navigate(['/categories']);
        }, () => {
            this.toastr.error('An error occurred on update the record.');
        });
    }
    cancel() {
        this.router.navigate(['/categories']);
    }
}
CategoryComponent.ɵfac = function CategoryComponent_Factory(t) { return new (t || CategoryComponent)(_angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdirectiveInject"](src_app_services_series_service__WEBPACK_IMPORTED_MODULE_0__.SeriesService), _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdirectiveInject"](_angular_router__WEBPACK_IMPORTED_MODULE_2__.Router), _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdirectiveInject"](_angular_router__WEBPACK_IMPORTED_MODULE_2__.ActivatedRoute), _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdirectiveInject"](ngx_toastr__WEBPACK_IMPORTED_MODULE_3__.ToastrService)); };
CategoryComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdefineComponent"]({ type: CategoryComponent, selectors: [["app-category"]], decls: 16, vars: 7, consts: [[1, "jumbtron"], ["autocomplete", "off", 1, "col-md-5", "form", 3, "submit"], ["form", "ngForm"], [1, "text-center", "text-primary"], ["type", "hidden", "name", "id", 3, "ngModel", "ngModelChange"], ["id", "ngModel"], [1, "form-group"], ["name", "name", "required", "", "placeholder", "Category", 1, "form-control", 3, "ngModel", "ngClass", "ngModelChange"], ["name", "ngModel"], ["class", "invalid-feedback", 4, "ngIf"], [1, "form-group", "text-center"], ["type", "submit", 1, "btn", "btn-success", "mr-2", 3, "disabled"], ["type", "button", 1, "btn", "btn-default", 3, "click"], [1, "invalid-feedback"]], template: function CategoryComponent_Template(rf, ctx) { if (rf & 1) {
        const _r4 = _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵgetCurrentView"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](0, "div", 0);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](1, "form", 1, 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵlistener"]("submit", function CategoryComponent_Template_form_submit_1_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵrestoreView"](_r4); const _r0 = _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵreference"](2); return ctx.onSubmit(_r0); });
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](3, "h2", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](4, "Category");
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](5, "input", 4, 5);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵlistener"]("ngModelChange", function CategoryComponent_Template_input_ngModelChange_5_listener($event) { return ctx.formData.id = $event; });
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](7, "div", 6);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](8, "input", 7, 8);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵlistener"]("ngModelChange", function CategoryComponent_Template_input_ngModelChange_8_listener($event) { return ctx.formData.name = $event; });
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtemplate"](10, CategoryComponent_div_10_Template, 2, 0, "div", 9);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](11, "div", 10);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](12, "button", 11);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](13, "Save");
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](14, "button", 12);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵlistener"]("click", function CategoryComponent_Template_button_click_14_listener() { return ctx.cancel(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](15, "Cancel");
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
    } if (rf & 2) {
        const _r0 = _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵreference"](2);
        const _r2 = _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵreference"](9);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](5);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵproperty"]("ngModel", ctx.formData.id);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](3);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵproperty"]("ngModel", ctx.formData.name)("ngClass", _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵpureFunction1"](5, _c0, (_r0.controls["name"] == null ? null : _r0.controls["name"].invalid) && (_r0.controls["name"] == null ? null : _r0.controls["name"].touched)));
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵproperty"]("ngIf", _r2.invalid && _r2.touched);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵproperty"]("disabled", _r0.invalid);
    } }, directives: [_angular_forms__WEBPACK_IMPORTED_MODULE_4__["ɵNgNoValidate"], _angular_forms__WEBPACK_IMPORTED_MODULE_4__.NgControlStatusGroup, _angular_forms__WEBPACK_IMPORTED_MODULE_4__.NgForm, _angular_forms__WEBPACK_IMPORTED_MODULE_4__.DefaultValueAccessor, _angular_forms__WEBPACK_IMPORTED_MODULE_4__.NgControlStatus, _angular_forms__WEBPACK_IMPORTED_MODULE_4__.NgModel, _angular_forms__WEBPACK_IMPORTED_MODULE_4__.RequiredValidator, _angular_common__WEBPACK_IMPORTED_MODULE_5__.NgClass, _angular_flex_layout_extended__WEBPACK_IMPORTED_MODULE_6__.DefaultClassDirective, _angular_common__WEBPACK_IMPORTED_MODULE_5__.NgIf], styles: [".form[_ngcontent-%COMP%] {\n    margin: 0 auto !important;\n    float: none !important;\n}\n\n.jumbtron[_ngcontent-%COMP%] {\n    padding-top: 60px;\n}\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbImNhdGVnb3J5LmNvbXBvbmVudC5jc3MiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IkFBQUE7SUFDSSx5QkFBeUI7SUFDekIsc0JBQXNCO0FBQzFCOztBQUVBO0lBQ0ksaUJBQWlCO0FBQ3JCIiwiZmlsZSI6ImNhdGVnb3J5LmNvbXBvbmVudC5jc3MiLCJzb3VyY2VzQ29udGVudCI6WyIuZm9ybSB7XG4gICAgbWFyZ2luOiAwIGF1dG8gIWltcG9ydGFudDtcbiAgICBmbG9hdDogbm9uZSAhaW1wb3J0YW50O1xufVxuXG4uanVtYnRyb24ge1xuICAgIHBhZGRpbmctdG9wOiA2MHB4O1xufSJdfQ== */"] });


/***/ }),

/***/ 3580:
/*!**********************************************************************!*\
  !*** ./src/app/confirmation-dialog/confirmation-dialog.component.ts ***!
  \**********************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "ConfirmationDialogComponent": () => (/* binding */ ConfirmationDialogComponent)
/* harmony export */ });
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @ng-bootstrap/ng-bootstrap */ 7544);


class ConfirmationDialogComponent {
    constructor(activeModal) {
        this.activeModal = activeModal;
    }
    ngOnInit() {
    }
    decline() {
        this.activeModal.close(false);
    }
    accept() {
        this.activeModal.close(true);
    }
    dismiss() {
        this.activeModal.dismiss();
    }
}
ConfirmationDialogComponent.ɵfac = function ConfirmationDialogComponent_Factory(t) { return new (t || ConfirmationDialogComponent)(_angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵdirectiveInject"](_ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_1__.NgbActiveModal)); };
ConfirmationDialogComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵdefineComponent"]({ type: ConfirmationDialogComponent, selectors: [["app-confirmation-dialog"]], inputs: { title: "title", message: "message", btnOkText: "btnOkText", btnCancelText: "btnCancelText" }, decls: 13, vars: 4, consts: [[1, "modal-header"], ["id", "modal-title", 1, "modal-title"], ["type", "button", "aria-describedby", "modal-title", 1, "close", 3, "click"], ["aria-hidden", "true"], [1, "modal-body"], [1, "modal-footer"], ["type", "button", 1, "btn", "btn-info", 3, "click"], ["type", "button", 1, "btn", "btn-danger", 3, "click"]], template: function ConfirmationDialogComponent_Template(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](0, "div", 0);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](1, "h4", 1);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](3, "button", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵlistener"]("click", function ConfirmationDialogComponent_Template_button_click_3_listener() { return ctx.dismiss(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](4, "span", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](5, "\u00D7");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](6, "div", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](7);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](8, "div", 5);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](9, "button", 6);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵlistener"]("click", function ConfirmationDialogComponent_Template_button_click_9_listener() { return ctx.dismiss(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](10);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](11, "button", 7);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵlistener"]("click", function ConfirmationDialogComponent_Template_button_click_11_listener() { return ctx.accept(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](12);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
    } if (rf & 2) {
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtextInterpolate"](ctx.title);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](5);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtextInterpolate1"](" ", ctx.message, "\n");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](3);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtextInterpolate"](ctx.btnCancelText);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtextInterpolate1"](" ", ctx.btnOkText, "");
    } }, styles: ["\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IiIsImZpbGUiOiJjb25maXJtYXRpb24tZGlhbG9nLmNvbXBvbmVudC5jc3MifQ== */"] });


/***/ }),

/***/ 7297:
/*!************************************************!*\
  !*** ./src/app/datepicker/datepicker-popup.ts ***!
  \************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "NgbdDatepickerPopup": () => (/* binding */ NgbdDatepickerPopup)
/* harmony export */ });
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @ng-bootstrap/ng-bootstrap */ 7544);
/* harmony import */ var _angular_forms__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @angular/forms */ 587);



class NgbdDatepickerPopup {
    constructor() { }
    ngOnInit() {
    }
}
NgbdDatepickerPopup.ɵfac = function NgbdDatepickerPopup_Factory(t) { return new (t || NgbdDatepickerPopup)(); };
NgbdDatepickerPopup.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵdefineComponent"]({ type: NgbdDatepickerPopup, selectors: [["ngbd-datepicker-popup"]], inputs: { placeholder: "placeholder" }, decls: 5, vars: 2, consts: [[1, "input-group"], ["name", "dp", "ngbDatepicker", "", 1, "form-control", 3, "placeholder", "ngModel", "ngModelChange"], ["d", "ngbDatepicker"], [1, "input-group-append"], ["type", "button", 1, "btn", "btn-outline-secondary", "fa", "fa-calendar-alt", 3, "click"]], template: function NgbdDatepickerPopup_Template(rf, ctx) { if (rf & 1) {
        const _r1 = _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵgetCurrentView"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](0, "div", 0);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](1, "input", 1, 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵlistener"]("ngModelChange", function NgbdDatepickerPopup_Template_input_ngModelChange_1_listener($event) { return ctx.model = $event; });
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](3, "div", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](4, "button", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵlistener"]("click", function NgbdDatepickerPopup_Template_button_click_4_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵrestoreView"](_r1); const _r0 = _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵreference"](2); return _r0.toggle(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
    } if (rf & 2) {
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("placeholder", ctx.placeholder)("ngModel", ctx.model);
    } }, directives: [_ng_bootstrap_ng_bootstrap__WEBPACK_IMPORTED_MODULE_1__.NgbInputDatepicker, _angular_forms__WEBPACK_IMPORTED_MODULE_2__.DefaultValueAccessor, _angular_forms__WEBPACK_IMPORTED_MODULE_2__.NgControlStatus, _angular_forms__WEBPACK_IMPORTED_MODULE_2__.NgModel], encapsulation: 2 });


/***/ }),

/***/ 2258:
/*!*************************************************!*\
  !*** ./src/app/failedConnection.interceptor.ts ***!
  \*************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "retryCount": () => (/* binding */ retryCount),
/* harmony export */   "retryWaitMilliSeconds": () => (/* binding */ retryWaitMilliSeconds),
/* harmony export */   "FailedConnectionInterceptor": () => (/* binding */ FailedConnectionInterceptor)
/* harmony export */ });
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! rxjs */ 4139);
/* harmony import */ var rxjs__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! rxjs */ 6587);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! rxjs/operators */ 6774);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! rxjs/operators */ 1133);
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! rxjs/operators */ 5843);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! @angular/core */ 3184);



const retryCount = 300;
const retryWaitMilliSeconds = 10 * 1000;
class FailedConnectionInterceptor {
    constructor() { }
    intercept(request, next) {
        return next.handle(request).pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_0__.retryWhen)(error => error.pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_1__.concatMap)((error, count) => {
            // if (count <= retryCount && (error.status == 0 ||error.status == 502 || error.status == 503 || error.status == 504)) 
            if ((error.url.includes('marks/add') || error.url.includes('files/updatePosition')) && count <= retryCount && (error.status == 0 || error.status == 502 || error.status == 503 || error.status == 504))
                return (0,rxjs__WEBPACK_IMPORTED_MODULE_2__.of)(error);
            return (0,rxjs__WEBPACK_IMPORTED_MODULE_3__.throwError)(error);
        }), (0,rxjs_operators__WEBPACK_IMPORTED_MODULE_4__.delay)(retryWaitMilliSeconds))));
    }
}
FailedConnectionInterceptor.ɵfac = function FailedConnectionInterceptor_Factory(t) { return new (t || FailedConnectionInterceptor)(); };
FailedConnectionInterceptor.ɵprov = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_5__["ɵɵdefineInjectable"]({ token: FailedConnectionInterceptor, factory: FailedConnectionInterceptor.ɵfac });


/***/ }),

/***/ 7205:
/*!****************************************!*\
  !*** ./src/app/home/home.component.ts ***!
  \****************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "HomeComponent": () => (/* binding */ HomeComponent)
/* harmony export */ });
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/router */ 2816);


const _c0 = function () { return ["/books/series"]; };
const _c1 = function () { return ["/books/soviet"]; };
const _c2 = function () { return ["/books/sovietfairytale"]; };
const _c3 = function () { return ["/books/animation"]; };
const _c4 = function () { return ["/audio/child"]; };
const _c5 = function () { return ["/books/balley"]; };
const _c6 = function () { return ["/books/film"]; };
const _c7 = function () { return ["/books/other"]; };
const _c8 = function () { return ["/books/youtube"]; };
const _c9 = function () { return ["/audio/main"]; };
const _c10 = function () { return ["/books/latest"]; };
class HomeComponent {
    constructor() { }
    ngOnInit() {
        (new MutationObserver(function (mutations, observer) {
            var _a, _b;
            for (let i = 0; i < mutations.length; i++) {
                const m = mutations[i];
                if (m.type == 'childList') {
                    for (let k = 0; k < m.addedNodes.length; k++) {
                        const autofocuses = m.addedNodes[k].querySelectorAll("[autofocus]"); //Note: this ignores the fragment's root element
                        console.log(autofocuses);
                        if (autofocuses.length) {
                            const a = autofocuses[autofocuses.length - 1]; // focus last autofocus element
                            (_a = a) === null || _a === void 0 ? void 0 : _a.focus();
                            (_b = a) === null || _b === void 0 ? void 0 : _b.select();
                        }
                    }
                }
            }
        })).observe(document.body, { attributes: false, childList: true, subtree: true });
    }
}
HomeComponent.ɵfac = function HomeComponent_Factory(t) { return new (t || HomeComponent)(); };
HomeComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵdefineComponent"]({ type: HomeComponent, selectors: [["app-home"]], decls: 24, vars: 22, consts: [[1, "container", "text-center"], [1, "btn-group-vertical"], [1, "btn", "btn-success", "btn-lg", 3, "routerLink"], [1, "btn", "btn-info", "btn-lg", 3, "routerLink"]], template: function HomeComponent_Template(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](0, "div", 0);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](1, "div", 1);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](2, "button", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](3, "\u041C\u0443\u043B\u044C\u0442\u0441\u0435\u0440\u0438\u0430\u043B\u044B");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](4, "button", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](5, "\u0421\u043E\u0432\u0435\u0442\u0441\u043A\u0438\u0435 \u043C\u0443\u043B\u044C\u0442\u0438\u043A\u0438");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](6, "button", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](7, "\u0421\u043E\u0432\u0435\u0442\u0441\u043A\u0438\u0435 \u0441\u043A\u0430\u0437\u043A\u0438");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](8, "button", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](9, "\u0417\u0430\u0440\u0443\u0431\u0435\u0436\u043D\u044B\u0435 \u043C\u0443\u043B\u044C\u0442\u0438\u043A\u0438");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](10, "button", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](11, "\u0410\u0443\u0434\u0438\u043E\u0441\u043A\u0430\u0437\u043A\u0438");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](12, "button", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](13, "\u0411\u0430\u043B\u0435\u0442");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](14, "button", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](15, "\u0424\u0438\u043B\u044C\u043C\u044B");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](16, "button", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](17, "\u0421\u0435\u0440\u0438\u0430\u043B\u044B \u0438 \u043A\u0443\u0440\u0441\u044B");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](18, "button", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](19, "Youtube");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](20, "button", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](21, "\u0410\u0443\u0434\u0438\u043E");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementStart"](22, "button", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵtext"](23, "\u041D\u0435\u0434\u0430\u0432\u043D\u0435\u0435");
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵelementEnd"]();
    } if (rf & 2) {
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](11, _c0));
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](12, _c1));
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](13, _c2));
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](14, _c3));
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](15, _c4));
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](16, _c5));
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](17, _c6));
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](18, _c7));
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](19, _c8));
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](20, _c9));
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵadvance"](2);
        _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵproperty"]("routerLink", _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵpureFunction0"](21, _c10));
    } }, directives: [_angular_router__WEBPACK_IMPORTED_MODULE_1__.RouterLink], styles: [".btn[_ngcontent-%COMP%]{\r\n    margin: 15px;\r\n}\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbImhvbWUuY29tcG9uZW50LmNzcyJdLCJuYW1lcyI6W10sIm1hcHBpbmdzIjoiQUFBQTtJQUNJLFlBQVk7QUFDaEIiLCJmaWxlIjoiaG9tZS5jb21wb25lbnQuY3NzIiwic291cmNlc0NvbnRlbnQiOlsiLmJ0bntcclxuICAgIG1hcmdpbjogMTVweDtcclxufVxyXG4iXX0= */"] });


/***/ }),

/***/ 610:
/*!******************************************!*\
  !*** ./src/app/login/login.component.ts ***!
  \******************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "LoginComponent": () => (/* binding */ LoginComponent)
/* harmony export */ });
/* harmony import */ var rxjs_operators__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! rxjs/operators */ 4661);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_router__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! @angular/router */ 2816);
/* harmony import */ var _services_auth_service__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../_services/auth.service */ 4167);
/* harmony import */ var _angular_forms__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! @angular/forms */ 587);
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! @angular/common */ 6362);






function LoginComponent_div_13_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](0, "div", 11);
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](1, " \u041F\u0440\u043E\u0432\u0430\u043B\u0435\u043D\u043E! \u041F\u043E\u043F\u0440\u043E\u0431\u0443\u0439\u0442\u0435 \u0435\u0449\u0435 \u0440\u0430\u0437! ");
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
} }
class LoginComponent {
    constructor(route, router, authService) {
        this.route = route;
        this.router = router;
        this.authService = authService;
        this.busy = false;
        this.username = '';
        this.password = '';
        this.loginError = false;
        this.subscription = null;
    }
    ngOnInit() {
        this.subscription = this.authService.user$.subscribe((x) => {
            if (this.route.snapshot.url[0].path === 'login') {
                const accessToken = localStorage.getItem('access_token');
                const refreshToken = localStorage.getItem('refresh_token');
                if (x && accessToken && refreshToken) {
                    const returnUrl = this.route.snapshot.queryParams['returnUrl'] || '';
                    this.router.navigate([returnUrl]);
                }
            } // optional touch-up: if a tab shows login page, then refresh the page to reduce duplicate login
        });
    }
    login() {
        if (!this.username || !this.password) {
            return;
        }
        this.busy = true;
        const returnUrl = this.route.snapshot.queryParams['returnUrl'] || '';
        this.authService
            .login(this.username, this.password)
            .pipe((0,rxjs_operators__WEBPACK_IMPORTED_MODULE_2__.finalize)(() => (this.busy = false)))
            .subscribe(() => {
            this.router.navigate([returnUrl]);
        }, () => {
            this.loginError = true;
        });
    }
    ngOnDestroy() {
        var _a;
        (_a = this.subscription) === null || _a === void 0 ? void 0 : _a.unsubscribe();
    }
}
LoginComponent.ɵfac = function LoginComponent_Factory(t) { return new (t || LoginComponent)(_angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdirectiveInject"](_angular_router__WEBPACK_IMPORTED_MODULE_3__.ActivatedRoute), _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdirectiveInject"](_angular_router__WEBPACK_IMPORTED_MODULE_3__.Router), _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdirectiveInject"](_services_auth_service__WEBPACK_IMPORTED_MODULE_0__.AuthService)); };
LoginComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdefineComponent"]({ type: LoginComponent, selectors: [["app-login"]], decls: 16, vars: 4, consts: [[1, "text-center", "mb-4"], ["src", "assets/img/logo.jpg", "alt", "logo", "loading", "lazy", "width", "180", "height", "180", 1, "mb-4", "rounded-circle"], [1, "h1", "mb-3", 2, "font-size", "60px", "font-family", "serif"], [1, "form-signin", 3, "ngSubmit"], [1, "form-label-group"], ["type", "text", "id", "userName", "name", "username", "placeholder", "Username", "required", "", "autofocus", "", 1, "form-control", 3, "ngModel", "ngModelChange"], ["for", "userName"], ["type", "password", "id", "inputPassword", "name", "password", "placeholder", "Password", "required", "", 1, "form-control", 3, "ngModel", "ngModelChange"], ["for", "inputPassword"], ["class", "checkbox mb-3 text-danger", 4, "ngIf"], ["type", "submit", 1, "btn", "btn-lg", "btn-primary", "btn-block", 3, "disabled"], [1, "checkbox", "mb-3", "text-danger"]], template: function LoginComponent_Template(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](0, "div", 0);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelement"](1, "img", 1);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](2, "h1", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](3, "LocalTube");
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](4, "form", 3);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵlistener"]("ngSubmit", function LoginComponent_Template_form_ngSubmit_4_listener() { return ctx.login(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](5, "div", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](6, "input", 5);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵlistener"]("ngModelChange", function LoginComponent_Template_input_ngModelChange_6_listener($event) { return ctx.username = $event; });
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](7, "label", 6);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](8, "\u0418\u043C\u044F \u043F\u043E\u043B\u044C\u0437\u043E\u0432\u0430\u0442\u0435\u043B\u044F");
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](9, "div", 4);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](10, "input", 7);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵlistener"]("ngModelChange", function LoginComponent_Template_input_ngModelChange_10_listener($event) { return ctx.password = $event; });
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](11, "label", 8);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](12, "\u041F\u0430\u0440\u043E\u043B\u044C");
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtemplate"](13, LoginComponent_div_13_Template, 2, 0, "div", 9);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](14, "button", 10);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](15, " \u0417\u0430\u0439\u0442\u0438 ");
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
    } if (rf & 2) {
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](6);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵproperty"]("ngModel", ctx.username);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](4);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵproperty"]("ngModel", ctx.password);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](3);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵproperty"]("ngIf", ctx.loginError);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](1);
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵproperty"]("disabled", ctx.busy);
    } }, directives: [_angular_forms__WEBPACK_IMPORTED_MODULE_4__["ɵNgNoValidate"], _angular_forms__WEBPACK_IMPORTED_MODULE_4__.NgControlStatusGroup, _angular_forms__WEBPACK_IMPORTED_MODULE_4__.NgForm, _angular_forms__WEBPACK_IMPORTED_MODULE_4__.DefaultValueAccessor, _angular_forms__WEBPACK_IMPORTED_MODULE_4__.RequiredValidator, _angular_forms__WEBPACK_IMPORTED_MODULE_4__.NgControlStatus, _angular_forms__WEBPACK_IMPORTED_MODULE_4__.NgModel, _angular_common__WEBPACK_IMPORTED_MODULE_5__.NgIf], styles: ["[_nghost-%COMP%]{\r\n  display: flex;\r\n  flex-direction: column;\r\n  align-items: center;\r\n  justify-content: center;\r\n  height: 100%;\r\n}\r\n\r\n.form-signin[_ngcontent-%COMP%] {\r\n  width: 100%;\r\n  max-width: 420px;\r\n  padding: 15px;\r\n}\r\n\r\n.form-label-group[_ngcontent-%COMP%] {\r\n  position: relative;\r\n  margin-bottom: 1rem;\r\n}\r\n\r\n.form-label-group[_ngcontent-%COMP%]    > input[_ngcontent-%COMP%], .form-label-group[_ngcontent-%COMP%]    > label[_ngcontent-%COMP%] {\r\n  height: 3.125rem;\r\n  padding: 0.75rem;\r\n}\r\n\r\n.form-label-group[_ngcontent-%COMP%]    > label[_ngcontent-%COMP%] {\r\n  position: absolute;\r\n  top: 0;\r\n  left: 0;\r\n  display: block;\r\n  width: 100%;\r\n  margin-bottom: 0; \r\n  line-height: 1.5;\r\n  color: #495057;\r\n  pointer-events: none;\r\n  cursor: text; \r\n  border: 1px solid transparent;\r\n  border-radius: 0.25rem;\r\n  transition: all 0.1s ease-in-out;\r\n}\r\n\r\n.form-label-group[_ngcontent-%COMP%]   input[_ngcontent-%COMP%]::-moz-placeholder {\r\n  color: transparent;\r\n}\r\n\r\n.form-label-group[_ngcontent-%COMP%]   input[_ngcontent-%COMP%]::placeholder {\r\n  color: transparent;\r\n}\r\n\r\n.form-label-group[_ngcontent-%COMP%]   input[_ngcontent-%COMP%]:not(:-moz-placeholder-shown) {\r\n  padding-top: 1.25rem;\r\n  padding-bottom: 0.25rem;\r\n}\r\n\r\n.form-label-group[_ngcontent-%COMP%]   input[_ngcontent-%COMP%]:not(:placeholder-shown) {\r\n  padding-top: 1.25rem;\r\n  padding-bottom: 0.25rem;\r\n}\r\n\r\n.form-label-group[_ngcontent-%COMP%]   input[_ngcontent-%COMP%]:not(:-moz-placeholder-shown)    ~ label[_ngcontent-%COMP%] {\r\n  padding-top: 0.25rem;\r\n  padding-bottom: 0.25rem;\r\n  font-size: 12px;\r\n  color: #777;\r\n}\r\n\r\n.form-label-group[_ngcontent-%COMP%]   input[_ngcontent-%COMP%]:not(:placeholder-shown)    ~ label[_ngcontent-%COMP%] {\r\n  padding-top: 0.25rem;\r\n  padding-bottom: 0.25rem;\r\n  font-size: 12px;\r\n  color: #777;\r\n}\r\n\r\n\r\n\r\n@supports (-ms-ime-align: auto) {\r\n  .form-label-group[_ngcontent-%COMP%]    > label[_ngcontent-%COMP%] {\r\n    display: none;\r\n  }\r\n  .form-label-group[_ngcontent-%COMP%]   input[_ngcontent-%COMP%]::-ms-input-placeholder {\r\n    color: #777;\r\n  }\r\n}\r\n\r\n\r\n\r\n@media all and (-ms-high-contrast: none), (-ms-high-contrast: active) {\r\n  .form-label-group[_ngcontent-%COMP%]    > label[_ngcontent-%COMP%] {\r\n    display: none;\r\n  }\r\n  .form-label-group[_ngcontent-%COMP%]   input[_ngcontent-%COMP%]:-ms-input-placeholder {\r\n    color: #777;\r\n  }\r\n}\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbImxvZ2luLmNvbXBvbmVudC5jc3MiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6IkFBQUE7RUFDRSxhQUFhO0VBQ2Isc0JBQXNCO0VBQ3RCLG1CQUFtQjtFQUNuQix1QkFBdUI7RUFDdkIsWUFBWTtBQUNkOztBQUVBO0VBQ0UsV0FBVztFQUNYLGdCQUFnQjtFQUNoQixhQUFhO0FBQ2Y7O0FBRUE7RUFDRSxrQkFBa0I7RUFDbEIsbUJBQW1CO0FBQ3JCOztBQUVBOztFQUVFLGdCQUFnQjtFQUNoQixnQkFBZ0I7QUFDbEI7O0FBRUE7RUFDRSxrQkFBa0I7RUFDbEIsTUFBTTtFQUNOLE9BQU87RUFDUCxjQUFjO0VBQ2QsV0FBVztFQUNYLGdCQUFnQixFQUFFLHNDQUFzQztFQUN4RCxnQkFBZ0I7RUFDaEIsY0FBYztFQUNkLG9CQUFvQjtFQUNwQixZQUFZLEVBQUUsb0NBQW9DO0VBQ2xELDZCQUE2QjtFQUM3QixzQkFBc0I7RUFDdEIsZ0NBQWdDO0FBQ2xDOztBQWNBO0VBQ0Usa0JBQWtCO0FBQ3BCOztBQUVBO0VBQ0Usa0JBQWtCO0FBQ3BCOztBQUVBO0VBQ0Usb0JBQW9CO0VBQ3BCLHVCQUF1QjtBQUN6Qjs7QUFIQTtFQUNFLG9CQUFvQjtFQUNwQix1QkFBdUI7QUFDekI7O0FBRUE7RUFDRSxvQkFBb0I7RUFDcEIsdUJBQXVCO0VBQ3ZCLGVBQWU7RUFDZixXQUFXO0FBQ2I7O0FBTEE7RUFDRSxvQkFBb0I7RUFDcEIsdUJBQXVCO0VBQ3ZCLGVBQWU7RUFDZixXQUFXO0FBQ2I7O0FBRUEsc0JBQXNCOztBQUN0QjtFQUNFO0lBQ0UsYUFBYTtFQUNmO0VBQ0E7SUFDRSxXQUFXO0VBQ2I7QUFDRjs7QUFFQSxvQkFBb0I7O0FBQ3BCO0VBQ0U7SUFDRSxhQUFhO0VBQ2Y7RUFDQTtJQUNFLFdBQVc7RUFDYjtBQUNGIiwiZmlsZSI6ImxvZ2luLmNvbXBvbmVudC5jc3MiLCJzb3VyY2VzQ29udGVudCI6WyI6aG9zdHtcclxuICBkaXNwbGF5OiBmbGV4O1xyXG4gIGZsZXgtZGlyZWN0aW9uOiBjb2x1bW47XHJcbiAgYWxpZ24taXRlbXM6IGNlbnRlcjtcclxuICBqdXN0aWZ5LWNvbnRlbnQ6IGNlbnRlcjtcclxuICBoZWlnaHQ6IDEwMCU7XHJcbn1cclxuXHJcbi5mb3JtLXNpZ25pbiB7XHJcbiAgd2lkdGg6IDEwMCU7XHJcbiAgbWF4LXdpZHRoOiA0MjBweDtcclxuICBwYWRkaW5nOiAxNXB4O1xyXG59XHJcblxyXG4uZm9ybS1sYWJlbC1ncm91cCB7XHJcbiAgcG9zaXRpb246IHJlbGF0aXZlO1xyXG4gIG1hcmdpbi1ib3R0b206IDFyZW07XHJcbn1cclxuXHJcbi5mb3JtLWxhYmVsLWdyb3VwID4gaW5wdXQsXHJcbi5mb3JtLWxhYmVsLWdyb3VwID4gbGFiZWwge1xyXG4gIGhlaWdodDogMy4xMjVyZW07XHJcbiAgcGFkZGluZzogMC43NXJlbTtcclxufVxyXG5cclxuLmZvcm0tbGFiZWwtZ3JvdXAgPiBsYWJlbCB7XHJcbiAgcG9zaXRpb246IGFic29sdXRlO1xyXG4gIHRvcDogMDtcclxuICBsZWZ0OiAwO1xyXG4gIGRpc3BsYXk6IGJsb2NrO1xyXG4gIHdpZHRoOiAxMDAlO1xyXG4gIG1hcmdpbi1ib3R0b206IDA7IC8qIE92ZXJyaWRlIGRlZmF1bHQgYDxsYWJlbD5gIG1hcmdpbiAqL1xyXG4gIGxpbmUtaGVpZ2h0OiAxLjU7XHJcbiAgY29sb3I6ICM0OTUwNTc7XHJcbiAgcG9pbnRlci1ldmVudHM6IG5vbmU7XHJcbiAgY3Vyc29yOiB0ZXh0OyAvKiBNYXRjaCB0aGUgaW5wdXQgdW5kZXIgdGhlIGxhYmVsICovXHJcbiAgYm9yZGVyOiAxcHggc29saWQgdHJhbnNwYXJlbnQ7XHJcbiAgYm9yZGVyLXJhZGl1czogMC4yNXJlbTtcclxuICB0cmFuc2l0aW9uOiBhbGwgMC4xcyBlYXNlLWluLW91dDtcclxufVxyXG5cclxuLmZvcm0tbGFiZWwtZ3JvdXAgaW5wdXQ6Oi13ZWJraXQtaW5wdXQtcGxhY2Vob2xkZXIge1xyXG4gIGNvbG9yOiB0cmFuc3BhcmVudDtcclxufVxyXG5cclxuLmZvcm0tbGFiZWwtZ3JvdXAgaW5wdXQ6LW1zLWlucHV0LXBsYWNlaG9sZGVyIHtcclxuICBjb2xvcjogdHJhbnNwYXJlbnQ7XHJcbn1cclxuXHJcbi5mb3JtLWxhYmVsLWdyb3VwIGlucHV0OjotbXMtaW5wdXQtcGxhY2Vob2xkZXIge1xyXG4gIGNvbG9yOiB0cmFuc3BhcmVudDtcclxufVxyXG5cclxuLmZvcm0tbGFiZWwtZ3JvdXAgaW5wdXQ6Oi1tb3otcGxhY2Vob2xkZXIge1xyXG4gIGNvbG9yOiB0cmFuc3BhcmVudDtcclxufVxyXG5cclxuLmZvcm0tbGFiZWwtZ3JvdXAgaW5wdXQ6OnBsYWNlaG9sZGVyIHtcclxuICBjb2xvcjogdHJhbnNwYXJlbnQ7XHJcbn1cclxuXHJcbi5mb3JtLWxhYmVsLWdyb3VwIGlucHV0Om5vdCg6cGxhY2Vob2xkZXItc2hvd24pIHtcclxuICBwYWRkaW5nLXRvcDogMS4yNXJlbTtcclxuICBwYWRkaW5nLWJvdHRvbTogMC4yNXJlbTtcclxufVxyXG5cclxuLmZvcm0tbGFiZWwtZ3JvdXAgaW5wdXQ6bm90KDpwbGFjZWhvbGRlci1zaG93bikgfiBsYWJlbCB7XHJcbiAgcGFkZGluZy10b3A6IDAuMjVyZW07XHJcbiAgcGFkZGluZy1ib3R0b206IDAuMjVyZW07XHJcbiAgZm9udC1zaXplOiAxMnB4O1xyXG4gIGNvbG9yOiAjNzc3O1xyXG59XHJcblxyXG4vKiBGYWxsYmFjayBmb3IgRWRnZSAqL1xyXG5Ac3VwcG9ydHMgKC1tcy1pbWUtYWxpZ246IGF1dG8pIHtcclxuICAuZm9ybS1sYWJlbC1ncm91cCA+IGxhYmVsIHtcclxuICAgIGRpc3BsYXk6IG5vbmU7XHJcbiAgfVxyXG4gIC5mb3JtLWxhYmVsLWdyb3VwIGlucHV0OjotbXMtaW5wdXQtcGxhY2Vob2xkZXIge1xyXG4gICAgY29sb3I6ICM3Nzc7XHJcbiAgfVxyXG59XHJcblxyXG4vKiBGYWxsYmFjayBmb3IgSUUgKi9cclxuQG1lZGlhIGFsbCBhbmQgKC1tcy1oaWdoLWNvbnRyYXN0OiBub25lKSwgKC1tcy1oaWdoLWNvbnRyYXN0OiBhY3RpdmUpIHtcclxuICAuZm9ybS1sYWJlbC1ncm91cCA+IGxhYmVsIHtcclxuICAgIGRpc3BsYXk6IG5vbmU7XHJcbiAgfVxyXG4gIC5mb3JtLWxhYmVsLWdyb3VwIGlucHV0Oi1tcy1pbnB1dC1wbGFjZWhvbGRlciB7XHJcbiAgICBjb2xvcjogIzc3NztcclxuICB9XHJcbn1cclxuIl19 */"] });


/***/ }),

/***/ 7823:
/*!**************************************************!*\
  !*** ./src/app/markslist/markslist.component.ts ***!
  \**************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "MarkslistComponent": () => (/* binding */ MarkslistComponent)
/* harmony export */ });
/* harmony import */ var _models_Mark__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../_models/Mark */ 4552);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _services_file_service__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../_services/file.service */ 5878);
/* harmony import */ var _angular_material_button__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! @angular/material/button */ 7317);
/* harmony import */ var _angular_material_icon__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! @angular/material/icon */ 5590);
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! @angular/common */ 6362);
/* harmony import */ var _angular_flex_layout_extended__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! @angular/flex-layout/extended */ 3338);
/* harmony import */ var _angular_material_form_field__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! @angular/material/form-field */ 4770);
/* harmony import */ var _angular_material_input__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! @angular/material/input */ 3365);
/* harmony import */ var _angular_forms__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! @angular/forms */ 587);
/* harmony import */ var _models_SeekPosition__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../_models/SeekPosition */ 9248);











const _c0 = ["audioElement"];
function MarkslistComponent_div_4_button_5_Template(rf, ctx) { if (rf & 1) {
    const _r7 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](0, "button", 8);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](1, "mat-icon", 9);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("click", function MarkslistComponent_div_4_button_5_Template_mat_icon_click_1_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r7); const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit; const ctx_r5 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"](); return ctx_r5.restoreMark(mark_r1); });
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](2, "refresh");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
} }
function MarkslistComponent_div_4_div_6_Template(rf, ctx) { if (rf & 1) {
    const _r10 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](0, "div", 10);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](1, "button", 11);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](2, "mat-icon", 9);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("click", function MarkslistComponent_div_4_div_6_Template_mat_icon_click_2_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r10); const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit; const ctx_r8 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"](); return ctx_r8.deleteMark(mark_r1); });
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](3, "delete");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](4, "button", 12);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("click", function MarkslistComponent_div_4_div_6_Template_button_click_4_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r10); const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit; const ctx_r11 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"](); return ctx_r11.rewindMark(mark_r1); });
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](5, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](6, "fast_rewind");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](7, "button", 12);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("click", function MarkslistComponent_div_4_div_6_Template_button_click_7_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r10); const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit; const ctx_r13 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"](); return ctx_r13.forwardMark(mark_r1); });
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](8, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](9, "fast_forward");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](10, "button", 12);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("click", function MarkslistComponent_div_4_div_6_Template_button_click_10_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r10); const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit; const ctx_r15 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"](); return ctx_r15.edit(mark_r1); });
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](11, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](12, "edit");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
} }
function MarkslistComponent_div_4_div_7_Template(rf, ctx) { if (rf & 1) {
    const _r19 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](0, "div");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](1, "mat-form-field", 13);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](2, "mat-label");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](3, "\u041D\u0430\u0437\u0432\u0430\u043D\u0438\u0435 \u043C\u0435\u0442\u043A\u0438");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](4, "input", 14);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("ngModelChange", function MarkslistComponent_div_4_div_7_Template_input_ngModelChange_4_listener($event) { _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r19); const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit; return mark_r1.caption = $event; })("keyup.enter", function MarkslistComponent_div_4_div_7_Template_input_keyup_enter_4_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r19); const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit; const ctx_r20 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"](); return ctx_r20.stopEdit(mark_r1, true); })("keyup.esc", function MarkslistComponent_div_4_div_7_Template_input_keyup_esc_4_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r19); const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit; const ctx_r22 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"](); return ctx_r22.stopEdit(mark_r1, false); });
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](5, "button", 12);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("click", function MarkslistComponent_div_4_div_7_Template_button_click_5_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r19); const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit; const ctx_r24 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"](); return ctx_r24.stopEdit(mark_r1, true); });
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](6, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](7, "done");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](8, "button", 15);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("click", function MarkslistComponent_div_4_div_7_Template_button_click_8_listener() { _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r19); const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit; const ctx_r26 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"](); return ctx_r26.stopEdit(mark_r1, false); });
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](9, "mat-icon");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](10, "cancel");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
} if (rf & 2) {
    const mark_r1 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"]().$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵadvance"](4);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵproperty"]("ngModel", mark_r1.caption);
} }
const _c1 = function (a0) { return { "deleted": a0 }; };
function MarkslistComponent_div_4_Template(rf, ctx) { if (rf & 1) {
    const _r30 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](0, "div", 3);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](2, "a", 4);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("click", function MarkslistComponent_div_4_Template_a_click_2_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵrestoreView"](_r30); const mark_r1 = restoredCtx.$implicit; const ctx_r29 = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵnextContext"](); return ctx_r29.markClicked(mark_r1); });
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵpipe"](4, "durationDisplay");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtemplate"](5, MarkslistComponent_div_4_button_5_Template, 3, 0, "button", 5);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtemplate"](6, MarkslistComponent_div_4_div_6_Template, 13, 0, "div", 6);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtemplate"](7, MarkslistComponent_div_4_div_7_Template, 11, 1, "div", 7);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
} if (rf & 2) {
    const mark_r1 = ctx.$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵproperty"]("ngClass", _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵpureFunction1"](8, _c1, mark_r1.isDeleted));
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtextInterpolate1"](" ", mark_r1.caption || "\u041C\u0435\u0442\u043A\u0430", " \u0432 ");
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtextInterpolate"](_angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵpipeBind1"](4, 6, mark_r1.position));
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵproperty"]("ngIf", mark_r1.isDeleted);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵproperty"]("ngIf", !mark_r1.isDeleted);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵadvance"](1);
    _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵproperty"]("ngIf", mark_r1.isInEditMode);
} }
class MarkslistComponent {
    constructor(service) {
        this.service = service;
        this.marks = [];
    }
    ngOnInit() {
        this.newMediaLoaded(this.videoId);
    }
    bigFont(event) {
        event.preventDefault();
        this.addMark();
    }
    addMark() {
        var element = this.getVideoElement();
        const timeDifference = 5;
        let position = element.currentTime - timeDifference;
        if (position < 0)
            position = 0;
        var mark = new _models_Mark__WEBPACK_IMPORTED_MODULE_0__.Mark();
        mark.dbFileId = this.videoId;
        mark.position = position;
        mark.isInEditMode = true;
        if (this.marks.find(x => Math.abs((x.position - mark.position)) < 5))
            return;
        this.createMark(mark);
        this.marks.push(mark);
    }
    createMark(mark) {
        this.service.addMarkByFile(mark).subscribe((id) => {
            mark.id = id;
        });
    }
    ngOnChanges(changes) {
        if (changes['videoId'] != null) {
            this.newMediaLoaded(this.videoId);
        }
    }
    paused() {
        if (this.getVideoElement().seeking)
            return;
        this.lastVolumeChangedTime = new Date();
    }
    played() {
        this.calculateTimeDiff(this.lastVolumeChangedTime, () => this.addMark(), () => { });
    }
    calculateTimeDiff(date, callbackOnLess, callbackOnMore) {
        var timeDiff = this.calculateTime(date);
        if (timeDiff < 2000) {
            callbackOnLess();
        }
        else {
            callbackOnMore();
        }
    }
    calculateTime(date) {
        return new Date().getTime() - date.getTime();
    }
    getVideoElement() {
        // if (!this.mediaElement)
        {
            let audio = document.querySelector('#player');
            var mediaEl = audio;
            if (!this._subscribed) {
                mediaEl.onpause = (event) => this.paused();
                mediaEl.onplay = (event) => this.played();
                this._subscribed = true;
            }
            return mediaEl;
        }
    }
    markClicked(mark) {
        if (mark.isDeleted)
            return;
        var element = this.getVideoElement();
        element.currentTime = mark.position;
    }
    deleteMark(mark) {
        this.service.deleteMark(mark.id).subscribe();
        mark.isDeleted = true;
        mark.isInEditMode = false;
        // this.marks = this.marks.filter((obj) => {
        //   return obj.id !== mark.id;
        // });
    }
    restoreMark(mark) {
        mark.id = 0;
        mark.isDeleted = false;
        this.createMark(mark);
    }
    rewindMark(mark) {
        mark.position -= 10;
        this.service.updateMark(mark).subscribe();
    }
    forwardMark(mark) {
        mark.position += 10;
        this.service.updateMark(mark).subscribe();
    }
    edit(mark) {
        mark.isInEditMode = true;
    }
    stopEdit(mark, applyEdit) {
        mark.isInEditMode = false;
        if (applyEdit)
            this.service.updateMark(mark).subscribe();
    }
    newMediaLoaded(fileId) {
        if (!fileId)
            return;
        this.videoId = fileId;
        this.service.getMarksByFile(this.videoId).subscribe((marks) => {
            this.getVideoElement();
            this.marks = marks.sort((a, b) => a.position - b.position);
        });
    }
    click() {
        console.log(this.videoId);
        this.newMediaLoaded(this.videoId);
        // let audio = document.querySelector(
        //   'audio'
        // );
        // console.log(audio);
    }
}
MarkslistComponent.ɵfac = function MarkslistComponent_Factory(t) { return new (t || MarkslistComponent)(_angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵdirectiveInject"](_services_file_service__WEBPACK_IMPORTED_MODULE_1__.FileService)); };
MarkslistComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵdefineComponent"]({ type: MarkslistComponent, selectors: [["app-markslist"]], viewQuery: function MarkslistComponent_Query(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵviewQuery"](_c0, 5);
    } if (rf & 2) {
        let _t;
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵqueryRefresh"](_t = _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵloadQuery"]()) && (ctx.audio = _t.first);
    } }, hostBindings: function MarkslistComponent_HostBindings(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("keydown.control.m", function MarkslistComponent_keydown_control_m_HostBindingHandler($event) { return ctx.bigFont($event); }, false, _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵresolveWindow"]);
    } }, inputs: { videoId: "videoId" }, features: [_angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵNgOnChangesFeature"]], decls: 5, vars: 1, consts: [["mat-icon-button", "", "color", "primary", "data-toggle", "tooltip", "data-placement", "top", "title", "\u0414\u043E\u0431\u0430\u0432\u0438\u0442\u044C \u043C\u0435\u0442\u043A\u0443 (ctrl+M)", 3, "click"], ["id", "marksList"], [3, "ngClass", 4, "ngFor", "ngForOf"], [3, "ngClass"], [1, "link-primary", 3, "click"], ["mat-icon-button", "", "class", "text-success", 4, "ngIf"], ["class", "inline", 4, "ngIf"], [4, "ngIf"], ["mat-icon-button", "", 1, "text-success"], [3, "click"], [1, "inline"], ["mat-icon-button", "", "color", "accent"], ["mat-icon-button", "", "color", "primary", 3, "click"], ["appearance", "fill", 1, "example-full-width"], ["matInput", "", "autofocus", "", 3, "ngModel", "ngModelChange", "keyup.enter", "keyup.esc"], ["mat-icon-button", "", "color", "accent", 3, "click"]], template: function MarkslistComponent_Template(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](0, "button", 0);
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵlistener"]("click", function MarkslistComponent_Template_button_click_0_listener() { return ctx.addMark(); });
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](1, "mat-icon");
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtext"](2, "bookmark");
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementStart"](3, "div", 1);
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵtemplate"](4, MarkslistComponent_div_4_Template, 8, 10, "div", 2);
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵelementEnd"]();
    } if (rf & 2) {
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵadvance"](4);
        _angular_core__WEBPACK_IMPORTED_MODULE_3__["ɵɵproperty"]("ngForOf", ctx.marks);
    } }, directives: [_angular_material_button__WEBPACK_IMPORTED_MODULE_4__.MatButton, _angular_material_icon__WEBPACK_IMPORTED_MODULE_5__.MatIcon, _angular_common__WEBPACK_IMPORTED_MODULE_6__.NgForOf, _angular_common__WEBPACK_IMPORTED_MODULE_6__.NgClass, _angular_flex_layout_extended__WEBPACK_IMPORTED_MODULE_7__.DefaultClassDirective, _angular_common__WEBPACK_IMPORTED_MODULE_6__.NgIf, _angular_material_form_field__WEBPACK_IMPORTED_MODULE_8__.MatFormField, _angular_material_form_field__WEBPACK_IMPORTED_MODULE_8__.MatLabel, _angular_material_input__WEBPACK_IMPORTED_MODULE_9__.MatInput, _angular_forms__WEBPACK_IMPORTED_MODULE_10__.DefaultValueAccessor, _angular_forms__WEBPACK_IMPORTED_MODULE_10__.NgControlStatus, _angular_forms__WEBPACK_IMPORTED_MODULE_10__.NgModel], pipes: [_models_SeekPosition__WEBPACK_IMPORTED_MODULE_2__.DurationDisplayPipe], styles: ["a[_ngcontent-%COMP%]{\n    color: rgb(0, 123, 255) !important;\n    -webkit-text-decoration-style: solid;\n            text-decoration-style: solid;\n    cursor:pointer ;\n}\n\n#marksList[_ngcontent-%COMP%]{\n    max-height: 280px;\n    \n    overflow: auto;\n    width: auto;\n}\n\n.deleted[_ngcontent-%COMP%]{\n    opacity: 0.5;\n}\n\n.inline[_ngcontent-%COMP%]{\n    display: inline;\n}\n\n.text-success[_ngcontent-%COMP%]{\n    opacity: 1;\n}\n\nbutton[mat-icon-button][_ngcontent-%COMP%] {\n  transform: scale(1.5);\n}\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbIm1hcmtzbGlzdC5jb21wb25lbnQuY3NzIl0sIm5hbWVzIjpbXSwibWFwcGluZ3MiOiJBQUFBO0lBQ0ksa0NBQWtDO0lBQ2xDLG9DQUE0QjtZQUE1Qiw0QkFBNEI7SUFDNUIsZUFBZTtBQUNuQjs7QUFFQTtJQUNJLGlCQUFpQjtJQUNqQiwrQkFBK0I7SUFDL0IsY0FBYztJQUNkLFdBQVc7QUFDZjs7QUFFQTtJQUNJLFlBQVk7QUFDaEI7O0FBRUE7SUFDSSxlQUFlO0FBQ25COztBQUVBO0lBQ0ksVUFBVTtBQUNkOztBQUVBO0VBQ0UscUJBQXFCO0FBQ3ZCIiwiZmlsZSI6Im1hcmtzbGlzdC5jb21wb25lbnQuY3NzIiwic291cmNlc0NvbnRlbnQiOlsiYXtcbiAgICBjb2xvcjogcmdiKDAsIDEyMywgMjU1KSAhaW1wb3J0YW50O1xuICAgIHRleHQtZGVjb3JhdGlvbi1zdHlsZTogc29saWQ7XG4gICAgY3Vyc29yOnBvaW50ZXIgO1xufVxuXG4jbWFya3NMaXN0e1xuICAgIG1heC1oZWlnaHQ6IDI4MHB4O1xuICAgIC8qIG92ZXJzY3JvbGwtYmVoYXZpb3I6IG5vbmU7ICovXG4gICAgb3ZlcmZsb3c6IGF1dG87XG4gICAgd2lkdGg6IGF1dG87XG59XG5cbi5kZWxldGVke1xuICAgIG9wYWNpdHk6IDAuNTtcbn1cblxuLmlubGluZXtcbiAgICBkaXNwbGF5OiBpbmxpbmU7XG59XG5cbi50ZXh0LXN1Y2Nlc3N7XG4gICAgb3BhY2l0eTogMTtcbn1cblxuYnV0dG9uW21hdC1pY29uLWJ1dHRvbl0ge1xuICB0cmFuc2Zvcm06IHNjYWxlKDEuNSk7XG59Il19 */"] });


/***/ }),

/***/ 3789:
/*!**************************************!*\
  !*** ./src/app/nav/nav.component.ts ***!
  \**************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "NavComponent": () => (/* binding */ NavComponent)
/* harmony export */ });
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! @angular/core */ 3184);

class NavComponent {
    constructor() { }
    ngOnInit() {
    }
}
NavComponent.ɵfac = function NavComponent_Factory(t) { return new (t || NavComponent)(); };
NavComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_0__["ɵɵdefineComponent"]({ type: NavComponent, selectors: [["app-nav"]], decls: 0, vars: 0, template: function NavComponent_Template(rf, ctx) { }, styles: [".title-home[_ngcontent-%COMP%] {\n    padding-top: 60px;\n }\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbIm5hdi5jb21wb25lbnQuY3NzIl0sIm5hbWVzIjpbXSwibWFwcGluZ3MiOiJBQUFBO0lBQ0ksaUJBQWlCO0NBQ3BCIiwiZmlsZSI6Im5hdi5jb21wb25lbnQuY3NzIiwic291cmNlc0NvbnRlbnQiOlsiLnRpdGxlLWhvbWUge1xuICAgIHBhZGRpbmctdG9wOiA2MHB4O1xuIH0iXX0= */"] });


/***/ }),

/***/ 9140:
/*!**********************************************************!*\
  !*** ./src/app/positionslist/positionslist.component.ts ***!
  \**********************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "PositionslistComponent": () => (/* binding */ PositionslistComponent)
/* harmony export */ });
/* harmony import */ var _models_SeekPosition__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../_models/SeekPosition */ 9248);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _angular_common__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @angular/common */ 6362);




function PositionslistComponent_div_0_li_4_Template(rf, ctx) { if (rf & 1) {
    const _r4 = _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵgetCurrentView"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](0, "li");
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](1, " \u0421\u043A\u0430\u0447\u043E\u043A \u0441 ");
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](2, "a", 3);
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵlistener"]("click", function PositionslistComponent_div_0_li_4_Template_a_click_2_listener() { const restoredCtx = _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵrestoreView"](_r4); const el_r2 = restoredCtx.$implicit; const ctx_r3 = _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵnextContext"](2); return ctx_r3.clicked(el_r2); });
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵpipe"](4, "durationDisplay");
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](5);
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵpipe"](6, "durationDisplay");
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
} if (rf & 2) {
    const el_r2 = ctx.$implicit;
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](3);
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtextInterpolate"](_angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵpipeBind1"](4, 2, el_r2.originalPosition));
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](2);
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtextInterpolate1"](" \u043D\u0430 ", _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵpipeBind1"](6, 4, el_r2.newPosition), " ");
} }
function PositionslistComponent_div_0_Template(rf, ctx) { if (rf & 1) {
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](0, "div", 1);
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](1, "h4");
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtext"](2, "\u0418\u0441\u0442\u043E\u0440\u0438\u044F \u043D\u0430\u0432\u0438\u0433\u0430\u0446\u0438\u0439");
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementStart"](3, "ul");
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtemplate"](4, PositionslistComponent_div_0_li_4_Template, 7, 6, "li", 2);
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵelementEnd"]();
} if (rf & 2) {
    const ctx_r0 = _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵnextContext"]();
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵadvance"](4);
    _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵproperty"]("ngForOf", ctx_r0.positions.seekPositions);
} }
class PositionslistComponent {
    constructor() {
        this.positions = new _models_SeekPosition__WEBPACK_IMPORTED_MODULE_0__.SeekPositionCollection();
    }
    ngOnInit() {
    }
    clicked(position) {
        var element = this.getVideoElement();
        element.currentTime = position.originalPosition;
    }
    getVideoElement() {
        let audio = document.querySelector('#player');
        var mediaEl = audio;
        return mediaEl;
    }
}
PositionslistComponent.ɵfac = function PositionslistComponent_Factory(t) { return new (t || PositionslistComponent)(); };
PositionslistComponent.ɵcmp = /*@__PURE__*/ _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵdefineComponent"]({ type: PositionslistComponent, selectors: [["app-positionslist"]], inputs: { positions: "positions" }, decls: 1, vars: 1, consts: [["id", "positionsList", 4, "ngIf"], ["id", "positionsList"], [4, "ngFor", "ngForOf"], [1, "link-primary", 3, "click"]], template: function PositionslistComponent_Template(rf, ctx) { if (rf & 1) {
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵtemplate"](0, PositionslistComponent_div_0_Template, 5, 1, "div", 0);
    } if (rf & 2) {
        _angular_core__WEBPACK_IMPORTED_MODULE_1__["ɵɵproperty"]("ngIf", ctx.positions.seekPositions.length > 0);
    } }, directives: [_angular_common__WEBPACK_IMPORTED_MODULE_2__.NgIf, _angular_common__WEBPACK_IMPORTED_MODULE_2__.NgForOf], pipes: [_models_SeekPosition__WEBPACK_IMPORTED_MODULE_0__.DurationDisplayPipe], styles: ["a[_ngcontent-%COMP%]{\n    color: rgb(0, 123, 255) !important;\n    -webkit-text-decoration-style: solid;\n            text-decoration-style: solid;\n    cursor:pointer ;\n}\n\n#positionsList[_ngcontent-%COMP%]{\n    max-height: 120px;\n    overflow: auto;\n    width: auto;\n}\n/*# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbInBvc2l0aW9uc2xpc3QuY29tcG9uZW50LmNzcyJdLCJuYW1lcyI6W10sIm1hcHBpbmdzIjoiO0FBQ0E7SUFDSSxrQ0FBa0M7SUFDbEMsb0NBQTRCO1lBQTVCLDRCQUE0QjtJQUM1QixlQUFlO0FBQ25COztBQUVBO0lBQ0ksaUJBQWlCO0lBQ2pCLGNBQWM7SUFDZCxXQUFXO0FBQ2YiLCJmaWxlIjoicG9zaXRpb25zbGlzdC5jb21wb25lbnQuY3NzIiwic291cmNlc0NvbnRlbnQiOlsiXG5he1xuICAgIGNvbG9yOiByZ2IoMCwgMTIzLCAyNTUpICFpbXBvcnRhbnQ7XG4gICAgdGV4dC1kZWNvcmF0aW9uLXN0eWxlOiBzb2xpZDtcbiAgICBjdXJzb3I6cG9pbnRlciA7XG59XG5cbiNwb3NpdGlvbnNMaXN0e1xuICAgIG1heC1oZWlnaHQ6IDEyMHB4O1xuICAgIG92ZXJmbG93OiBhdXRvO1xuICAgIHdpZHRoOiBhdXRvO1xufSJdfQ== */"] });


/***/ }),

/***/ 4766:
/*!*****************************************!*\
  !*** ./src/environments/environment.ts ***!
  \*****************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "environment": () => (/* binding */ environment)
/* harmony export */ });
const environment = {
    production: false,
    // baseUrl: 'http://192.168.1.55:2022/'
    // baseUrl: 'https://3af0-80-68-9-86.ngrok-free.app/'
    baseUrl: 'http://192.168.1.55:51951/'
    // baseUrl: 'https://192.168.1.55:44343/'
};
// ng serve --host 0.0.0.0  Run in local network to access from phone


/***/ }),

/***/ 8835:
/*!*********************!*\
  !*** ./src/main.ts ***!
  \*********************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _angular_platform_browser__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! @angular/platform-browser */ 318);
/* harmony import */ var _angular_core__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @angular/core */ 3184);
/* harmony import */ var _app_app_module__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./app/app.module */ 23);
/* harmony import */ var _environments_environment__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./environments/environment */ 4766);




if (_environments_environment__WEBPACK_IMPORTED_MODULE_1__.environment.production) {
    (0,_angular_core__WEBPACK_IMPORTED_MODULE_2__.enableProdMode)();
}
_angular_platform_browser__WEBPACK_IMPORTED_MODULE_3__.platformBrowser().bootstrapModule(_app_app_module__WEBPACK_IMPORTED_MODULE_0__.AppModule)
    .catch(err => console.error(err));


/***/ }),

/***/ 6700:
/*!***************************************************!*\
  !*** ./node_modules/moment/locale/ sync ^\.\/.*$ ***!
  \***************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

var map = {
	"./af": 8685,
	"./af.js": 8685,
	"./ar": 254,
	"./ar-dz": 4312,
	"./ar-dz.js": 4312,
	"./ar-kw": 2614,
	"./ar-kw.js": 2614,
	"./ar-ly": 8630,
	"./ar-ly.js": 8630,
	"./ar-ma": 8674,
	"./ar-ma.js": 8674,
	"./ar-sa": 9032,
	"./ar-sa.js": 9032,
	"./ar-tn": 4730,
	"./ar-tn.js": 4730,
	"./ar.js": 254,
	"./az": 3052,
	"./az.js": 3052,
	"./be": 150,
	"./be.js": 150,
	"./bg": 3069,
	"./bg.js": 3069,
	"./bm": 3466,
	"./bm.js": 3466,
	"./bn": 8516,
	"./bn-bd": 557,
	"./bn-bd.js": 557,
	"./bn.js": 8516,
	"./bo": 6273,
	"./bo.js": 6273,
	"./br": 9588,
	"./br.js": 9588,
	"./bs": 9815,
	"./bs.js": 9815,
	"./ca": 3331,
	"./ca.js": 3331,
	"./cs": 1320,
	"./cs.js": 1320,
	"./cv": 2219,
	"./cv.js": 2219,
	"./cy": 8266,
	"./cy.js": 8266,
	"./da": 6427,
	"./da.js": 6427,
	"./de": 7435,
	"./de-at": 2871,
	"./de-at.js": 2871,
	"./de-ch": 2994,
	"./de-ch.js": 2994,
	"./de.js": 7435,
	"./dv": 2357,
	"./dv.js": 2357,
	"./el": 5649,
	"./el.js": 5649,
	"./en-au": 9961,
	"./en-au.js": 9961,
	"./en-ca": 9878,
	"./en-ca.js": 9878,
	"./en-gb": 3924,
	"./en-gb.js": 3924,
	"./en-ie": 864,
	"./en-ie.js": 864,
	"./en-il": 1579,
	"./en-il.js": 1579,
	"./en-in": 940,
	"./en-in.js": 940,
	"./en-nz": 6181,
	"./en-nz.js": 6181,
	"./en-sg": 4301,
	"./en-sg.js": 4301,
	"./eo": 5291,
	"./eo.js": 5291,
	"./es": 4529,
	"./es-do": 3764,
	"./es-do.js": 3764,
	"./es-mx": 2584,
	"./es-mx.js": 2584,
	"./es-us": 3425,
	"./es-us.js": 3425,
	"./es.js": 4529,
	"./et": 5203,
	"./et.js": 5203,
	"./eu": 678,
	"./eu.js": 678,
	"./fa": 3483,
	"./fa.js": 3483,
	"./fi": 6262,
	"./fi.js": 6262,
	"./fil": 2521,
	"./fil.js": 2521,
	"./fo": 4555,
	"./fo.js": 4555,
	"./fr": 3131,
	"./fr-ca": 8239,
	"./fr-ca.js": 8239,
	"./fr-ch": 1702,
	"./fr-ch.js": 1702,
	"./fr.js": 3131,
	"./fy": 267,
	"./fy.js": 267,
	"./ga": 3821,
	"./ga.js": 3821,
	"./gd": 1753,
	"./gd.js": 1753,
	"./gl": 4074,
	"./gl.js": 4074,
	"./gom-deva": 2762,
	"./gom-deva.js": 2762,
	"./gom-latn": 5969,
	"./gom-latn.js": 5969,
	"./gu": 2809,
	"./gu.js": 2809,
	"./he": 5402,
	"./he.js": 5402,
	"./hi": 315,
	"./hi.js": 315,
	"./hr": 410,
	"./hr.js": 410,
	"./hu": 8288,
	"./hu.js": 8288,
	"./hy-am": 8999,
	"./hy-am.js": 8999,
	"./id": 1334,
	"./id.js": 1334,
	"./is": 6959,
	"./is.js": 6959,
	"./it": 4864,
	"./it-ch": 1124,
	"./it-ch.js": 1124,
	"./it.js": 4864,
	"./ja": 6141,
	"./ja.js": 6141,
	"./jv": 9187,
	"./jv.js": 9187,
	"./ka": 2136,
	"./ka.js": 2136,
	"./kk": 4332,
	"./kk.js": 4332,
	"./km": 8607,
	"./km.js": 8607,
	"./kn": 4305,
	"./kn.js": 4305,
	"./ko": 234,
	"./ko.js": 234,
	"./ku": 6003,
	"./ku.js": 6003,
	"./ky": 5061,
	"./ky.js": 5061,
	"./lb": 2786,
	"./lb.js": 2786,
	"./lo": 6183,
	"./lo.js": 6183,
	"./lt": 29,
	"./lt.js": 29,
	"./lv": 4169,
	"./lv.js": 4169,
	"./me": 8577,
	"./me.js": 8577,
	"./mi": 8177,
	"./mi.js": 8177,
	"./mk": 337,
	"./mk.js": 337,
	"./ml": 5260,
	"./ml.js": 5260,
	"./mn": 2325,
	"./mn.js": 2325,
	"./mr": 4695,
	"./mr.js": 4695,
	"./ms": 5334,
	"./ms-my": 7151,
	"./ms-my.js": 7151,
	"./ms.js": 5334,
	"./mt": 3570,
	"./mt.js": 3570,
	"./my": 7963,
	"./my.js": 7963,
	"./nb": 8028,
	"./nb.js": 8028,
	"./ne": 6638,
	"./ne.js": 6638,
	"./nl": 302,
	"./nl-be": 6782,
	"./nl-be.js": 6782,
	"./nl.js": 302,
	"./nn": 3501,
	"./nn.js": 3501,
	"./oc-lnc": 563,
	"./oc-lnc.js": 563,
	"./pa-in": 869,
	"./pa-in.js": 869,
	"./pl": 5302,
	"./pl.js": 5302,
	"./pt": 9687,
	"./pt-br": 4884,
	"./pt-br.js": 4884,
	"./pt.js": 9687,
	"./ro": 9107,
	"./ro.js": 9107,
	"./ru": 3627,
	"./ru.js": 3627,
	"./sd": 355,
	"./sd.js": 355,
	"./se": 3427,
	"./se.js": 3427,
	"./si": 1848,
	"./si.js": 1848,
	"./sk": 4590,
	"./sk.js": 4590,
	"./sl": 184,
	"./sl.js": 184,
	"./sq": 6361,
	"./sq.js": 6361,
	"./sr": 8965,
	"./sr-cyrl": 1287,
	"./sr-cyrl.js": 1287,
	"./sr.js": 8965,
	"./ss": 5456,
	"./ss.js": 5456,
	"./sv": 451,
	"./sv.js": 451,
	"./sw": 7558,
	"./sw.js": 7558,
	"./ta": 2702,
	"./ta.js": 2702,
	"./te": 3693,
	"./te.js": 3693,
	"./tet": 1243,
	"./tet.js": 1243,
	"./tg": 2469,
	"./tg.js": 2469,
	"./th": 5768,
	"./th.js": 5768,
	"./tk": 7761,
	"./tk.js": 7761,
	"./tl-ph": 5780,
	"./tl-ph.js": 5780,
	"./tlh": 9590,
	"./tlh.js": 9590,
	"./tr": 3807,
	"./tr.js": 3807,
	"./tzl": 3857,
	"./tzl.js": 3857,
	"./tzm": 654,
	"./tzm-latn": 8806,
	"./tzm-latn.js": 8806,
	"./tzm.js": 654,
	"./ug-cn": 845,
	"./ug-cn.js": 845,
	"./uk": 9232,
	"./uk.js": 9232,
	"./ur": 7052,
	"./ur.js": 7052,
	"./uz": 7967,
	"./uz-latn": 2233,
	"./uz-latn.js": 2233,
	"./uz.js": 7967,
	"./vi": 8615,
	"./vi.js": 8615,
	"./x-pseudo": 2320,
	"./x-pseudo.js": 2320,
	"./yo": 1313,
	"./yo.js": 1313,
	"./zh-cn": 4490,
	"./zh-cn.js": 4490,
	"./zh-hk": 5910,
	"./zh-hk.js": 5910,
	"./zh-mo": 8262,
	"./zh-mo.js": 8262,
	"./zh-tw": 4223,
	"./zh-tw.js": 4223
};


function webpackContext(req) {
	var id = webpackContextResolve(req);
	return __webpack_require__(id);
}
function webpackContextResolve(req) {
	if(!__webpack_require__.o(map, req)) {
		var e = new Error("Cannot find module '" + req + "'");
		e.code = 'MODULE_NOT_FOUND';
		throw e;
	}
	return map[req];
}
webpackContext.keys = function webpackContextKeys() {
	return Object.keys(map);
};
webpackContext.resolve = webpackContextResolve;
module.exports = webpackContext;
webpackContext.id = 6700;

/***/ })

},
/******/ __webpack_require__ => { // webpackRuntimeModules
/******/ var __webpack_exec__ = (moduleId) => (__webpack_require__(__webpack_require__.s = moduleId))
/******/ __webpack_require__.O(0, ["vendor"], () => (__webpack_exec__(8835)));
/******/ var __webpack_exports__ = __webpack_require__.O();
/******/ }
]);
//# sourceMappingURL=main.js.map