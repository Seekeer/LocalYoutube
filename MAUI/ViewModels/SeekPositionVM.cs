using CommunityToolkit.Mvvm.ComponentModel;

namespace MAUI.ViewModels
{
    public class SeekPositionVM
    {
        public TimeSpan OriginalPosition { get; set; }
        public TimeSpan NewPosition { get; set; }

        public string OriginalPositionStr
        {
            get
            {
                if (OriginalPosition.TotalHours > 1)
                    return OriginalPosition.ToString(@"hh\:mm\:ss");
                else
                    return OriginalPosition.ToString(@"mm\:ss");
            }
        }
    }
    public partial class SeekPositionCollectionVM : ObservableObject
    {
        private List<TimeSpan> _lastPosition = new ();

        public TimeSpan GetCurrentPosition()
        {
            return _lastPosition.LastOrDefault();
        }

        [ObservableProperty]
        List<SeekPositionVM> _positions  = new List<SeekPositionVM>();

        // TODO - for some reason throw Ex on adding. Threads?
        //[ObservableProperty]
        //private ObservableCollection<SeekPosition> _positions = new ObservableCollection<SeekPosition>();

        public bool TryAddPosition(List<TimeSpan> positions, TimeSpan newPosition)
        {
            try
            {
                var diffPositions = positions.Where(x => Math.Abs((newPosition - x).TotalSeconds) > 5);
                var originalPosition = diffPositions.LastOrDefault();

                if (newPosition == originalPosition)
                    return false;

                if (this.Positions.Count > 0)
                {

                    var lastPosition = this.Positions[this.Positions.Count - 1];
                    if (lastPosition.OriginalPosition == originalPosition)
                    {
                        lastPosition.NewPosition = newPosition;
                        return false;
                    }
                }

                if (this.Positions.Any(x => x.NewPosition == newPosition && x.OriginalPosition == originalPosition))
                    return false;

                var seekPosition = new SeekPositionVM();
                seekPosition.OriginalPosition = originalPosition;
                seekPosition.NewPosition = newPosition;
                //this.Positions.Add(seekPosition);

                this.Positions.Insert(0, seekPosition);
                this.Positions = new List<SeekPositionVM>(this.Positions);
                return true;
            }
            catch (Exception ex)
            {
                return false;
            }
        }

        internal bool PositionUpdated(TimeSpan position)
        {
            if (!Positions.Any())
                Positions.Add(new SeekPositionVM { NewPosition = (position) });

            if (Math.Abs((Positions.First().NewPosition - position).TotalSeconds) > 2)
            {
                Positions.Insert(0, (new SeekPositionVM { NewPosition = (position), OriginalPosition = Positions.First().NewPosition }));
                this.Positions = new List<SeekPositionVM>(this.Positions.Take(2));
                return true;
            }
            else
            {
                Positions.First().NewPosition = position;
                return false;
            }
        }
    } 
}