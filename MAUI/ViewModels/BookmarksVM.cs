using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using MAUI.Services;
using System;
using System.Collections.ObjectModel;
using System.Security.Cryptography;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace MAUI.ViewModels
{
    public class MarkVM
    {
        public MarkVM() { }
        public MarkVM(MarkAddDto x)
        {
            Id = x.Id;
            Caption = x.Caption;
            DbFileId = x.DbFileId;
            Position = TimeSpan.FromSeconds(x.Position);
        }

        public int DbFileId { get; set; }
        public int Id { get; set; }
        public TimeSpan Position { get; set; }
        public string PositionStr
        {
            get
            {
                if (Position.TotalHours > 1)
                    return Position.ToString(@"hh\:mm\:ss");
                else
                    return Position.ToString(@"mm\:ss");
            }
        }
        public string Caption { get; set; }

        internal MarkAddDto GetDTO()
        {
            return new MarkAddDto
            {
                Id = Id,
                Caption = Caption,
                Position = Position.TotalSeconds,
                DbFileId = DbFileId
            };
        }

        public bool IsDifferenceGreater(MarkVM markVM, TimeSpan limit)
        {
            var diff = this.Position - markVM.Position;

            return Math.Abs(diff.TotalMilliseconds) > limit.TotalMilliseconds;
        }
    }

    public partial class BookmarksVM : ObservableObject
    {
        private int _fileId;
        private DateTime _lastCheckTime;
        private readonly IAPIService _api;
        private readonly Func<TimeSpan> _getPosition;

        [ObservableProperty]
        List<MarkVM> _marks = new ();
        //public ObservableCollection<MarkVM> Marks { get; } 

        public BookmarksVM(IAPIService api, Func<TimeSpan> getPosition, int fileId)
        {
            this._fileId = fileId;
            _api = api;
            _getPosition = getPosition;

            GetInfoAsync(fileId);
        }

        private async Task GetInfoAsync(int fileId)
        {
            Marks = (await _api.GetMarksForFile(fileId)).Select(x => new MarkVM(x)).ToList();
        }

        public void Paused()
        {
            _lastCheckTime = DateTime.Now;
        }

        public async Task Resumed()
        {
            var diffSeconds = (DateTime.Now - _lastCheckTime).TotalSeconds;
            if (diffSeconds < 5)
            {
                await AddMarkAsync(_getPosition());
            }
        }

        [RelayCommand]
        public async Task Delete(int id)
        {
            var mark = Marks.First(x => x.Id == id); 
            Marks.Remove(mark);
            UpdateMarks();
            await _api.DeleteMarkAsync(mark.Id);
        }

        // Need cause have problems with ObservCollection
        private void UpdateMarks()
        {
            Marks = new List<MarkVM>(Marks);
        }

        public async Task AddMarkAsync(TimeSpan time)
        {
            var markAddVM = new MarkVM
            {
                Caption = "Закладка",
                Position = time,
                DbFileId = _fileId,
            };

            if (Marks.Any(x => !x.IsDifferenceGreater(markAddVM, TimeSpan.FromSeconds(5))))
                return;

            markAddVM.Id = await _api.AddMarkAsync(markAddVM.GetDTO());
            // TODO Notify
            if(markAddVM.Id == 0)
                return;

            Marks.Add(markAddVM);
            UpdateMarks();
        }

    }
}