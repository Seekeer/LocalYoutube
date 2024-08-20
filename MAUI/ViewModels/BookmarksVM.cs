using Dtos;
using MAUI.Services;
using System.Collections.ObjectModel;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace MAUI.ViewModels
{
    public class MarkVM
    {
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
    }

    public class BookmarksVM
    {
        private int _fileId;
        private TimeSpan _lastCheckTime;
        private readonly IAPIService _api;
        private readonly Func<TimeSpan> _getPosition;

        private ObservableCollection<MarkVM> Marks { get; } 

        public BookmarksVM(IAPIService api, Func<TimeSpan> getPosition, int fileId)
        {
            this._fileId = fileId;
            _api = api;
            _getPosition = getPosition;

            Marks = new ObservableCollection<MarkVM>();
            Marks.Add(new MarkVM
            {
                Caption = "asdf",
                Position = TimeSpan.FromSeconds(555)
            });
            //Marks = new ObservableCollection<MarkVM>(_api.GetMarksForFile(fileId));
        }

        public void Paused()
        {
            _lastCheckTime = _getPosition();
        }

        public async Task Resumed()
        {
            var diffSeconds = (_lastCheckTime - _getPosition()).TotalSeconds;
            if (diffSeconds < 3)
            {
                await AddMarkAsync(_getPosition());
            }
        }

        public async Task AddMarkAsync(TimeSpan time)
        {
            var markAddVM = new MarkVM
            {
                Position = time,
                DbFileId = _fileId,
            };

            if (Marks.Any(x => (x.Position - markAddVM.Position) < TimeSpan.FromSeconds(5)))
                return;

            markAddVM.Id = await _api.AddMarkAsync(markAddVM.GetDTO());
            Marks.Add(markAddVM);
        }

        public async Task RemoveMarkAsync(MarkVM mark)
        {
            Marks.Remove(mark);
            await _api.RemoveMarkAsync(mark.Id);
        }
    }
}