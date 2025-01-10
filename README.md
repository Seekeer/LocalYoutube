# Local Tube
Self-hosted media stream service that allows you to download video from the Internet and watch it from your own server. 
You can think about it as a low-level version of Jellyfin but with some killer features such as:
- Telegram bot to easily send links to desired videos to download them from Youtube and trackers;
- Adding bookmarks to video;
- Mobile client with the ability to pre-download video;
- Ability to navigate to previous video position to undo accidental swipe on timeline

## Architecture
The backend is asp.net core application, frontend is Angular for Web and MAUI application for Desktop and Android (possibly iOs).

![image](https://github.com/user-attachments/assets/f41d06dd-48b6-4e73-836d-c7e998846006)

## Technologies
- .NET Core 
- MS SQL Server
- EF Core
- Quartz
- Telegram
- Torrent-tracker
- Yt-DLP
- Youtube API
- PhantomJS
- AngleSharp
- Polly
- SignalR
- Fluent API
- AutoMapper
- Swagger

### SPA
- Angular 
- Ng-Bootstrap
- Ngx-Toastr

### Mobile-desktop app
- MAUI 
- SignalR
